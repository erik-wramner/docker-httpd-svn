# Apache httpd with Subversion

This image provides Apache configured for use as a Subversion server. The docker file has been copied from [docker-library/httpd](https://github.com/docker-library/httpd)
and modified to build Subversion as well as Apache. It was a bit messy to use the official image as a base and compile Subversion afterwards as the two builds share
many build dependencies; otherwise that would have been nicer.
