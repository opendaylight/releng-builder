echo "Checking OSGi bundles..."
sshpass -p karaf "/tmp/${BUNDLEFOLDER}/bin/client" -u karaf 'bundle:list'
