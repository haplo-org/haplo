
KApp.in_every_application() { p KApp.global(:ssl_hostname); if(KPlugin.get('std_workflow')) then p 'reinstalling'; KPlugin.install_plugin('std_workflow') end }

