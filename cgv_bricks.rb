#
#            Automate Method
#
$evm.log("info", "cgv_bricks Automate Method Started **************************")
#
#            Method Code Goes here
#

@debug = true

console = $evm.object['dialog_cons']
cluster = $evm.object['dialog_cluster']
name = $evm.object['dialog_name']
type = $evm.object['dialog_type']
size = $evm.object['dialog_size']
gluster_systems = $evm.object['gluster_systems'].strip
userid = $evm.root['user'].userid



# Reading gluster console credentials from gluster_systems.txt file
for line in File.readlines(gluster_systems)
  line.strip!
  cred = line.split[1..1].join if line =~ /^#{console}/
end

# Downloading certificate from each system to /tmp/<FQDN>.gluster.crt
cert = "/tmp/#{console}.gluster.crt"
`wget -O #{cert} http://#{console}/ca.crt 2>/dev/null`


# Preparing curl syntax
curl = "curl 2> /dev/null -u #{cred} --cacert #{cert} https://#{console}"

# Looking for cluster id by name
for line in `#{curl}/api/clusters`.each_line 
  found = false
  clid = line.split('"')[3..3].join if line.include? "<cluster href="
  if line.include? "<name>#{cluster}<"
    found = true
    break
  end
end

unless found
  $evm.log("error","No cluster id found for name #{cluster}")  
  exit MIQ_ERROR
end



# Looking for clid's hosts
hosts = ""
for line in `#{curl}/api/hosts`.each_line 
  hostip = line.gsub(/<\/*address>/,"") if line.include? "<address>"
  if line.include? "#{clid}"
    hosts += hostip
  end
end

unless hosts.lines.count > 1
  $evm.log("error","Unable to find hosts for cluster #{cluster}")
  exit MIQ_ERROR
end

# Debug
$evm.log("info","\n\n======= debug ====>>>>> #{hosts}\n") if @debug

# Now it's decission time how many bricks we need. 
# One brick per host is enough unless we need replica and there is less than 4. 
# So if there are less that 4 hosts lets make twice as many bricks.
hosts += hosts if hosts.lines.count < 4 and type.include? "repl"

# Calculating brick size (lvsize) in MB. If the volume is not replicated it's just size/number of bricks. For repicated volumes double space is needed.
if type.include? "repl"
  space = size.to_i * 2
else
  space = size.to_i
end
lvsize = space / hosts.lines.count
#/ wt...???

# Creating logical volumes in the biggest available volume group on each host
n = 0
bricks = ""
for host in hosts.each_line
  host.strip!
  # Generating lvname
  n += 1
  lvname = "#{userid}_#{name}_#{n.to_s}"

  # Checking volume group name
  vg = `ssh #{host} vgs | awk '{print $NF,$1}' | sed -e 's/\.[0-9][0-9]g/000/g' -e 's/\.[0-9][0-9]t/000000/g' | sort -g | tail -1 | cut -d' ' -f2`.chomp

  # Creating xfs bricks 
  ssh = "ssh #{host}"
  `#{ssh} mkdir /#{lvname} 2>/dev/null`
  `#{ssh} lvcreate -n #{lvname} -L #{lvsize} #{vg} 2>/dev/null`
  `#{ssh} mkfs.xfs /dev/#{vg}/#{lvname} 2>/dev/null`
  `#{ssh} mount /dev/#{vg}/#{lvname} /#{lvname} 2>/dev/null`
  `#{ssh} mkdir /#{lvname}/brick 2>/dev/null`
  `#{ssh} "grep -q " /#{lvname} " /etc/fstab || echo /dev/#{vg}/#{lvname} /#{lvname} xfs defaults 0 0 >> /etc/fstab"`
  bricks += "#{host} /#{lvname}/brick\n"

  df = `#{ssh} df -H | grep -e Filesystem -e "[-/]#{userid}_#{name}_"`
  $evm.log("info","\n\n#{host}: ======= debug ====>>>>\n#{df}\n")
  
  unless df.lines.count > 1
    $evm.log("error","Failed to create bricks.")
    exit MIQ_ERROR
  end
  
end

# Passing list of created bricks
$evm.object['bricks'] = bricks
  

#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
