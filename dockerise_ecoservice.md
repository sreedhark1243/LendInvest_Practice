pull the eco service to your local repo. in my case i have pulled it on to C:\GITHUb\lendinvest\

create a folder structure so that it will be easy to run the docker compose file.

C:\GITHUb\lendinvest\echo-service\docker & C:\GITHUb\lendinvest\echo-service\docker\nginx

cd C:\GITHUb\lendinvest\echo-service\docker\nginx
create a nginx.config file and update the attached nginx.config content, or you can download and copy paste the file for easy use. PFA..

cd C:\GITHUb\lendinvest\echo-service\docker
create **dockerfile** and **docker-compose.yaml** files.

See the attached files and paste it the folder

Now with a single command you can create a docker image and run the container

docker-compose up -d

