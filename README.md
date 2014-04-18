cloudforms-gluster
==================

Red Hat CloudForms and Storage Integration

Things which needs to be ready in advance:

1. Gluster Storage systems with management console. Management console details must be put info 
   /var/www/miq/vmdb/gluster_systems.txt file on cloudforms appliance.

   example:
     root@cfme3# cat /var/www/miq/vmdb/gluster_systems.txt
     # Gluster storage systems definition file for Storage Service integration 
     # There must be name resolving and ssh key relationships set between CFME host and all gluster nodes: 
     #	root@cfme# ssh-copy-id node
     #
     # Syntax: <FQDN of gluster console host> <user>@<domain>:<password>
     # Example: rhsc.example.com admin@internal:redhat  
     #
     rhsc.example.com admin@internal:redhat

2. SSH keys distributed from cloudforms appliance to each gluster node 
   example:
     root@cfme3# ssh-copy-id rhs1.example.com

Project consists of 4 services:

1. List Gluster Storage (methods lgs_*)

2. Create Gluster Volume (methods cgv_*)

3. Extend Gluster Volume (methods egv_*)

4. Delete Glusater Volume (methods dgv_*)

