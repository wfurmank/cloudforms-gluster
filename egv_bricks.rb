#
#            Automate Method
#
$evm.log("info", "egv_bricks Automate Method Started **************************")
#
#            Method Code Goes here
#
@debug = true

console = $evm.object['dialog_cons']
console = "rhsc.example.com" if console.nil?
cluster = $evm.object['dialog_cluster']
cluster = "default" if cluster.nil?
name = $evm.object['dialog_name']
name = "admin_auth2" if name.nil?
#type = $evm.object['dialog_type']
#type = "distributed_replicate" if type.nil?
size = $evm.object['dialog_size']
size = "1000" if size.nil?
gluster_systems = $evm.object['gluster_systems'].strip
#userid = $evm.root['user'].userid



# Reading gluster console credentials from gluster_systems.txt file
for line in File.readlines(gluster_systems)
  line.strip!
  cred = line.split[1..1].join if line =~ /^#{console}/
end

# Downloading certificate from each system to /tmp/<FQDN>.gluster.crt
cert = "/tmp/#{console}.gluster.crt"
`wget -O #{cert} http://#{console}/ca.crt 2>/dev/null`

# Preparing curl syntax
curl = "curl -u #{cred} --cacert #{cert} https://#{console}"

# Looking for cluster id by name
for line in `#{curl}/api/clusters 2> /dev/null`.each_line 
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
for line in `#{curl}/api/hosts 2> /dev/null`.each_line 
  hostip = line.gsub(/<\/*address>/,"") if line.include? "<address>"
  if line.include? "#{clid}"
    hosts += hostip
  end
end

# Debug
$evm.log("info","\n\n======= debug ====>>>>> #{hosts}\n") if @debug

unless hosts.lines.count > 1
  $evm.log("error","Unable to find hosts for cluster #{cluster}")
  exit MIQ_ERROR
end

# Looking for volume id by name
for line in `#{curl}/api/clusters/#{clid}/glustervolumes 2> /dev/null`.each_line 
  found = false
  volid = line.split('"')[3..3].join if line.include? "<gluster_volume href="
  if line.include? "<name>#{name}<"
    found = true
    break
  end
end

unless found
  $evm.log("error","No volume id found for name #{name} in cluster #{cluster} at system #{console}")  
  exit MIQ_ERROR
end

# Checking number of replicas
for line in `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid} 2> /dev/null`.each_line 
  repl = line.split('>')[1..1].join.split('<')[0..0].join if line.include? "<replica_count>"
end

# Now its decission time how many bricks we need. One brick per host is enough unless we need replica and there is less than 4. So if there are less that 4 hosts lets make twice as many bricks.
hosts += hosts if hosts.lines.count < 4 and repl.to_i > 0

# Calculating brick size (lvsize) in MB. If the volume is not replicated it's just size/number of bricks. For repicated volumes double space is needed.
if repl.to_i == 0
  space = size.to_i
else
  space = size.to_i * repl.to_i
end
lvsize = space / hosts.lines.count
#/

# Calculates next brick number
n = 0
for line in `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid}/bricks 2> /dev/null`.each_line 
  n += 1 if line.include? "<brick href="
end
  
# Creating logical volumes in the biggest available volume group on each host
bricks = ""
for host in hosts.each_line
  host.strip!
  n += 1
  # Generating lvname
  lvname = "#{name}_#{n.to_s}"

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

  df = `#{ssh} df -H | grep -e Filesystem -e "[-/]#{name}_"`
  $evm.log("info","\n\n#{host}: ======= debug ====>>>>\n#{df}\n")
  
  unless df.lines.count > 1
    $evm.log("error","Failed to create bricks.")
    exit MIQ_ERROR
  end
end

$evm.object['bricks'] = bricks
  

#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
