#
#            Automate Method
#
$evm.log("info", "egv_volume Automate Method Started **************************")
#
#            Method Code Goes here
#

@debug = true

userid = $evm.root['user'].userid
gluster_systems = $evm.object['gluster_systems'].strip
console = $evm.object['dialog_cons']
cluster = $evm.object['dialog_cluster']
name = $evm.object['dialog_name']
bricks = $evm.object['bricks']

# Reading gluster console credentials from gluster_systems.txt file
for line in File.readlines(gluster_systems)
  line.strip!
  cred = line.split[1..1].join if line =~ /^#{console}/
end

# Downloading certificate from each system to /tmp/<FQDN>.gluster.crt
cert = "/tmp/" + console + ".gluster.crt"
`wget -O #{cert} http://#{console}/ca.crt 2>/dev/null`

# Preparing curl syntax
curl = "curl 2> /dev/null -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u #{cred} --cacert #{cert} https://#{console}"

# Looking for cluster id by name
found = false
for line in `#{curl}/api/clusters`.each_line 
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
found = false
for line in `#{curl}/api/clusters/#{clid}/glustervolumes`.each_line 
  volid = line.split('"')[3..3].join if line.include? "<gluster_volume href="
  if line.include? "<name>#{name}<"
    found = true
    break
  end
end

unless found
  $evm.log("error","No volume id found for name #{name} in cluster #{cluster} at #{console}")  
  $evm.log("error","curl syntax: #{curl}/api/clusters/#{clid}/glustervolumes")
  exit MIQ_ERROR
end

# Preparing API syntax
addbricks_href = "<bricks>"

for line in bricks.each_line
  hostip = line.split[0..0].join
  brickd = line.split[1..1].join

  # Looking for hostid by hostip
  for line in `#{curl}/api/hosts`.each_line 
    found = false
    hostid = line.split('"')[3..3].join if line.include? "<host href="
    if line.include? "<address>#{hostip}<"
      found = true
      break
    end
  end
  addbricks_href += "<brick><server_id>#{hostid}</server_id><brick_dir>#{brickd}</brick_dir></brick>"
end

unless found
  $evm.log("error","No host id found for ip #{hostip}")  
  exit MIQ_ERROR
end

addbricks_href +=  "</bricks>"

# Extending glustervolume
addbricks_output = `#{curl}/api/clusters/#{clid}/glustervolumes/#{volid}/bricks -X POST -d "#{addbricks_href}"`
# Debug
$evm.log("info","\n\naddbricks_output: #{addbricks_output}\n") if @debug


# Generating info about nfs_paths
nfs_paths = ""
for line in bricks.gsub(/ .*/,"").split.uniq
  #nfs_paths += "<br>" + line.gsub(/$/,":/#{name}") + "\n"
  nfs_paths += "<br>#{line}:/#{name}\n"
end

# Debug
$evm.log("info", "\n====== bricks =====>>>>>#{bricks}\n") if @debug
$evm.log("info", "\n====== bricks.gsub =====>>>>>#{bricks.gsub(/ .*/,"").split.uniq}\n") if @debug
$evm.log("info", "\n====== nfs_paths =====>>>>>#{nfs_paths}\n") if @debug

 
subject = "CloudForms: Extend Gluster Volume request"
body  = "<br>\n<br>Gluster-Console / Cluster / Volume:\n"
body += "<br>#{console} / #{cluster} / #{name}\n"
body += "<br>\n<br>Enjoy !\n"

# Debug
$evm.log("info", "\n==== subject ====>\n#{subject}<=====") if @debug
$evm.log("info", "\n==== body ====>\n#{body}<=====") if @debug

# Passing message content
$evm.object['message_subject'] = subject
$evm.object['message_body'] = body
  
#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
