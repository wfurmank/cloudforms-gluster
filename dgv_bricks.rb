#
#            Automate Method
#
$evm.log("info", "dgv_bricks Automate Method Started **************************")
#
#            Method Code Goes here
#

@debug = true

userid = $evm.root['user'].userid
gluster_systems = $evm.object['gluster_systems']
console = $evm.object['dialog_console']
cluster = $evm.object['dialog_cluster']
name = $evm.object['dialog_name']

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

unless hosts.lines.count > 1
  $evm.log("error","Unable to find hosts for cluster #{cluster}")
  exit MIQ_ERROR
end

# Cleaning up


for host in hosts.each_line
  host.strip!
  cleanup  = `ssh #{host} umount /#{name}_* 2>&1`
  cleanup += `ssh #{host} ls /#{name}_* && rm -rf /#{name}_* 2>&1`
  cleanup += `ssh #{host} sed -i '/#{name}_/d' /etc/fstab 2>&1`
  cleanup += `ssh #{host} lvremove -f /dev/*/#{name}_* 2>&1`
end

# Debug
$evm.log("info","\n\n====== cleanup =====>>>>>#{cleanup}\n") if @debug


#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
