# Execute the test ODL logs playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-logs.yaml -v
