# Simple bash script to collect metrics from dockers and host.

The script allow to post collected data into Elasticsearch and build visualisation with kibana. 
Just run the docker_compose from my github account to build Elasticsearch ENV.
Add a Linux service with systemd to start the monitor script at startup. 
The idea to use simple solution for free and do not use heavy application to monitor my instances.
Soon will add the AWS CLI docker to block DDOS attacks from China.  

![Kibana Screenshot](https://github.com/maks200179/monitor/blob/master/Kibana.bmp)
