#
#            Automate Method
#
$evm.log("info", "dgv_volume Automate Method Started **************************")
#
#            Method Code Goes here
#

@debug = true

userid = $evm.root['user'].userid
gluster_systems = $evm.object['gluster_systems']
console = $evm.object['dialog_console']
cluster = $evm.object['dialog_cluster']
name = $evm.object['dialog_name']

# Checking if user owns the volume or is admin
unless name =~ /^#{userid}_/ or userid == "admin"
  $evm.log("error","User #{userid} is trying to delete volume #{name} (not an owner)")
  exit MIQ_ERROR
end

# Reading gluster console credentials from gluster_systems.txt file
for line in File.readlines(gluster_systems)
  line.strip!
  cred = line.split[1..1].join if line =~ /^#{console}/
end

# Downloading certificate to /tmp/<console>.gluster.crt
cert = "/tmp/" + console + ".gluster.crt"
`wget -O #{cert} http://#{console}/ca.crt 2>/dev/null`

# Preparing curl syntax
curl = "curl 2> /dev/null -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u #{cred} --cacert #{cert} https://#{console}"

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

# Looking for volume id by name
for line in `#{curl}/api/clusters/#{clid}/glustervolumes`.each_line
  found = false
  volid = line.split('"')[3..3].join if line.include? "<gluster_volume href="
  if line.include? "<name>#{name}<"
   found = true
   break
  end
end

unless found
  $evm.log("error","No volume id found for name #{name}")  
  exit MIQ_ERROR
end

# Stopping volume
stop_output = `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid}/stop -d "<action/>"`

# Deleting volume
delete_output = `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid} -XDELETE`

# Debug
$evm.log("info","\n\n======= stopping volume =====>>>> #{stop_output}\n") if @debug
$evm.log("info","\n\n======= deleting volume =====>>>> #{delete_output}\n") if @debug

# Checking if volume still exists
if `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid}`.include? volid
  $evm.log("error","Failed to delete volume: #{name}, id: #{volid}")  
  exit MIQ_ERROR
end

#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
