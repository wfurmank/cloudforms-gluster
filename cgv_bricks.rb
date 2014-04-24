#
#            Automate Method
#
$evm.log("info", "lgs_read Automate Method Started ****************************")
#
#            Method Code Goes here
#

@debug = true

gluster_systems = $evm.object['gluster_systems']
user = $evm.root['user']
message = ""

# Reading gluster consoles from gluster_systems.txt file
consoles = ""
for line in File.readlines(gluster_systems)
  line = line.gsub(/#.*/,"").strip
  consoles += "#{line}\n" if line.split.size == 2
end

# Preparing list of user's volumes
volume_list = "<br>Gluster-Console / Cluster / Volume\n"

# Reading host details from each gluster console
for line in consoles.each_line
  line = line.gsub(/#.*/,"").strip
  if line.split.size == 2
    # Reading host FQDN ie: rhsc.example.com
    console = line.split[0..0].join
    # Reading credentials ie: admin@internal:redhat
    cred = line.split[1..1].join
  end
  
  # Downloading certificate from each system to /tmp/<FQDN>.gluster.crt
  cert = "/tmp/#{console}.gluster.crt"
  `wget -O #{cert} http://#{console}/ca.crt 2>/dev/null`

  # Preparing curl syntax
  curl = "curl 2> /dev/null -u #{cred} --cacert #{cert} https://#{console}"
    
  # Looking for cluster id of "gluster type" managed clusters
  clids = ""
  for line in `#{curl}/api/clusters`.each_line
    clid = line.split('"')[3..3].join if line.include? "<cluster href"
    clids += clid if line.include? "<gluster_service>true<"
  end
  
  for clid in clids.each_line
    clid.chomp!
    # looking for Cluster Name for given Cluster ID
    found = false
    for line in `#{curl}/api/clusters`.each_line
      found = true if line.include? clid
      if found and line.include? "<name>"
        clname = line.gsub(/<\/*name>/,"").strip
        break
      end
    end

    # Message header
    message += "<br>Gluster-Console: #{console}, Cluster: #{clname}\n"

    # Looking for user's volumes in each cluster
    volumes = `#{curl}/api/clusters/#{clid}/glustervolumes`
    for line in volumes.each_line
      if user.userid == "admin"
        volume_list += "<br>#{console} / #{clname} / #{line.gsub(/<\/*name>/,"").strip}\n" if line.include? "<name>"
      else
        volume_list += "<br>#{console} / #{clname} / #{line.gsub(/<\/*name>/,"").strip}\n" if line.include? "<name>#{user.userid}_"
      end
    end
    
    # Debug
    $evm.log("info","\n\nmessage =====>\n#{message}<===\n") if @debug
    
    
    # Looking for hosts' IP addresses in each "gluster type" cluster
    hosts = `#{curl}/api/hosts | grep -e '<address>' -e "#{clid}" | grep -B1 "#{clid}" | grep '<address>' | sed -e 's:.*<address>::g' -e 's:</address>.*::g'`
      
    # Checking free space in each host
    if ! hosts.empty?
      message += "<br>Host-IP / VG / Free-Space\n"
      for host in hosts.each_line do
        host.chomp!
        ssh_err = `ssh -o "ConnectTimeout 1" #{host} ls /etc/services 2>/dev/null >/dev/null || echo $?`
        if ssh_err.empty?
          message += `ssh #{host} vgs 2> /dev/null | grep -v Free | awk '{print $1,"/",$NF}' | xargs -l echo "<br>#{host} / "`
        else
          err = "Error: CFME is not able to run remote commands over ssh at host #{host}"
          $evm.log("error",err)
          message += err
          subject = "CloudForms: List Gluster Storage Request Error"
          exit = MIQ_ERROR
        end
      end
    end
    message += "<br>\n"
  end
end

if volume_list.split.size > 1
  message += "<br>Your existing gluster volumes:\n<br>\n"
  message += volume_list
end

# Debug
$evm.log("info", "\n\n===== message body =======>#{message}<====\n") if @debug

# Passing message content
$evm.object['message_body'] = message
$evm.object['message_subject'] = "CloudForms: List Gluster Storage Request"



#
#
#
$evm.log("info", "lgs_read Automate Method Ended")
exit MIQ_OK
