#
#            Automate Method
#
$evm.log("info", "cgv_error Automate Method Started ***************************")
#
#            Method Code Goes here
#

@debug = true

miq_server = $evm.root['miq_server']
user = $evm.root['user']
admin = $evm.vmdb('user').find_by_name("Administrator")
message = $evm.object['message_body']
subject = $evm.object['message_subject']
from = $evm.object['from']
to = user.email
to_admin = admin.email

subject += " ERROR"

# Formatting email mesage
body  = "Dear #{user.name},\n"
body += "<br>\n<br>An error has ocurred during your <i>Create Gluster Volume</i> request.\n"
body += "<br>The following message was generated.\n<br>\n"
body += "<br>The following Gluster Volume has been created:\n"
body += message
body += "<br>\n<br>\n<br>-----\n"
body += "<br>#{miq_server.hostname} CloudForms Management Engine\n<br>\n"

# Debug
$evm.log("info","\n\n==== user email body ====>#{body}<===\n") if @debug

# Sending user email
$evm.execute(:send_email,to,from,subject,body,content_type = nil)

# If user other than admin, send notification to admin
unless user.userid == "admin"
  # Admin email
  subject_admin = subject + " - User: #{user.name} (#{user.userid})"
  body_admin  = "Dear #{admin.name},\n"
  body_admin += "<br>\n<br>The following message was sent to user: #{user.name} (#{user.userid})\n<br>\n"
  body_admin += body

  # Debug
  $evm.log("info","\n\n==== admin email body ====>#{body_admin}<===\n") if @debug

  # Sending admin email
  $evm.execute(:send_email,to_admin,from,subject_admin,body_admin,content_type = nil)
end


#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
