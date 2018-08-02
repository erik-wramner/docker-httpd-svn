# Apache httpd with Subversion

This image provides Apache configured for use as a Subversion server. The docker file has been copied from [docker-library/httpd](https://github.com/docker-library/httpd)
and modified to build Subversion as well as Apache.

## Usage

To quickly get a Subversion server up and running with a test repository and a single user, run:

```
docker run -d -p 80:80 -e SVN_REPO_NAME=test -e SVN_USER=admin -e SVN_PASSWORD=securepassword httpd-svn
```

That creates a Subversion repository named test and exposes it to the user admin with password securepassword on port 80 without SSL.
For a slightly more realistic configuration run:

```
docker run -d --mount source=v_svn,target=/svn -p 443:443 -e HTTPD_SSL=on \
  -e HTTPD_SERVER_NAME=myhost.mydomain.com -e SVN_REPO_NAME=test \
  -e SVN_USER=admin -e SVN_PASSWORD=securepassword httpd-svn
```

That uses SSL with a self-signed certificate and the host name myhost.mydomain.com. It also uses a volume for the
Subversion repositories, configuration files and backup files.

For production use without a fronting load balancer:

```
docker run -d --name httpd-svn --mount source=v_svn,target=/svn \
  --mount type=bind,source="$(pwd)/server.crt",target=/usr/local/apache2/conf/server.crt,readonly \
  --mount type=bind,source="$(pwd)/server.key",target=/usr/local/apache2/conf/server.key,readonly \
  -p 443:443 -e HTTPD_SSL=on \
  -e HTTPD_SERVER_NAME=myhost.mydomain.com httpd-svn
```

This uses a real SSL certificate mapped into the container and a volume for the repositories, configuration files and backups.
Users are added manually:
```
docker exec -it httpd-svn /bin/bash
htpasswd -B /svn/config/svn-users someuser
```
Access rights are also defined manually, see /svn/config/svn-access. Repositories should be owned by httpd:
```
docker exec -it httpd-svn /bin/bash
svnadmin create /svn/repos/somerepo
chown -R httpd:httpd /svn/repos/somerepo
```

Backups can be created using the backup-svn-repos.sh script using an external cron job:
```
docker exec httpd-svn backup-svn-repos.sh
```

The backups are saved in the same volume as the repositories, so be sure to copy the files to another location as well.


## Notes

* It is important to set the ServerName option to the real external host name, as Subversion (or rather DAV) needs it for the copy command.
  Set HTTPD_SERVER_NAME when using the default configuration or be sure to set it manually. If not defined the container's host name will
  be used and that is probably wrong.
* It is a very good idea to require SSL/TLS or alternatively to use a web front with SSL.
