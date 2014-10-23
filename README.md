How to test locally
- Use the official Jenkins docker image "docker run -d -p 8080:8080 jenkins:weekly"
- Then install the Jenkins Plugin Dependencies as listed below
- Run JJB with "jenkins-jobs -l DEBUG --conf jenkins.ini update jjb"

Jenkins Plugin Dependencies
- Email-ext Plugin
- Gerrit Trigger Plugin
- Git Plugin
- Sonar Plugin
- SSH-Agent Plugin

