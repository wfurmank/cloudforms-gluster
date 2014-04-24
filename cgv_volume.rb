#
#            Automate Method
#
$evm.log("info", "cgv_volume Automate Method Started **************************")
#
#            Method Code Goes here
#

@debug = true

userid = $evm.root['user'].userid
gluster_systems = $evm.object['gluster_systems'].strip
console = $evm.object['dialog_cons']
cluster = $evm.object['dialog_cluster']
name = $evm.object['dialog_name']
type = $evm.object['dialog_type']
auth_allow = $evm.object['dialog_auth_allow'].strip
bricks = $evm.object['bricks']

# Setting replica count to 2. This can be later customized, for now the idea is to keep things simple.
if type == "distributed_replicate" 
  replica_count = "<replica_count>2</replica_count>"
else
  replica_count = ""
end


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


# Preparing API syntax
create_href = "<gluster_volume><name>#{userid}_#{name}</name><volume_type>#{type}</volume_type><bricks>"


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
  create_href += "<brick><server_id>#{hostid}</server_id><brick_dir>#{brickd}</brick_dir></brick>"
end

unless found
  $evm.log("error","No host id found for ip #{hostip}")  
  exit MIQ_ERROR
end

create_href +=  "</bricks>#{replica_count}</gluster_volume>"

# Creating glustervolume
create_output = `#{curl}/api/clusters/#{clid}/glustervolumes -X POST -d "#{create_href}"`
$evm.log("info","\n\n create_output: #{create_output}\n") if @debug

# Getting additional commands
for line in create_output.each_line
  setoption_href = line.split('"')[1..1].join if line.include? "/setoption"
  start_href = line.split('"')[1..1].join if line.include? "/start"
end

# Setting auth_allow option
setoption_output = `#{curl}#{setoption_href} -X POST -d "<action><option name=\\"auth.allow\\" value=\\"#{auth_allow}\\" /></action>"` unless setoption_href.nil?
$evm.log("info","\n\nsetoption_output: #{setoption_output}\n") if @debug

# Starting the volume
start_output = `#{curl}#{start_href} -X POST -d "<action/>" 2>/dev/null` unless start_href.nil?
$evm.log("info","\n\nstart_output: #{start_output}\n") if @debug


nfs_paths = ""
for line in bricks.gsub(/ .*/,"").split.uniq
  nfs_paths += "<br>" + line.gsub(/$/,":/#{userid}_#{name}") + "\n"
end

# Debug
$evm.log("info", "\n\n====== bricks =====>>>>>#{bricks}\n") if @debug
$evm.log("info", "\n\n====== bricks.gsub =====>>>>>#{bricks.gsub(/ .*/,"").split.uniq}\n") if @debug
$evm.log("info", "\n\n====== nfs_paths =====>>>>>#{nfs_paths}\n") if @debug

# Creating message content  
subject = "CloudForms: Create Gluster Volume request"
body  = "<br>\n<br>Gluster-Console / Cluster / Volume:\n"
body += "<br>#{console} / #{cluster} / #{userid}_#{name}\n"
body += "<br>\n<br>Mount one of the following nfs paths to access your new volme.\n"
body += "<br>#{nfs_paths}\n"
body += "<br>\n<br>The following IP addresses are allowed to mount the volume: #{auth_allow}\n"
body += "<br>\n<br>Enjoy !\n"

# Passing message content
$evm.object['message_subject'] = subject
$evm.object['message_body'] = body
  
#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
