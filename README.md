# Apache httpd with Subversion

This image provides Apache configured for use as a Subversion server. The docker file has been copied from [docker-library/httpd](https://github.com/docker-library/httpd)
and modified to build Subversion as well as Apache.

## Usage

To quickly get a Subversion server up and running with a test repository and a single user, run:

```
docker run -d -p 80:80 -e SVN_REPO_NAME=test -e SVN_USER=admin -e SVN_PASSWORD=securepassword httpd-svn
```

That creates a Subversion repository named test and exposes it to the user admin with password securepassword on port 80 without SSL.
The repository can be accessed at http://localhost/svn/test.

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
  --mount type=bind,source="$(pwd)/localcerts",target=/etc/ssl/localcerts,readonly \
  -p 443:443 -e HTTPD_SSL=on \
  -e HTTPD_SERVER_NAME=myhost.mydomain.com httpd-svn
```

This uses a real SSL certificate (represented by server.crt and server.key in localcerts) mapped into the container
and a volume for the repositories, configuration files and backups. Users are added manually:
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

## Configuration

There are many configuration options. It should be possible to use this image as is. The Apache configuration file
(httpd.conf) is present in /svn/config in the /svn volume. That means it is possible to edit the configuration; the
changes will persist. The same applies to the users and access rules (also in /svn/config) and of course to the
repositories.

The SSL certificates are stored in /etc/ssl/localcerts and can be replaced (see above). If intermediate certs are
needed the httpd.conf file must be edited to include them, though.

The following options are supported without the need for manual changes:
* HTTPD_SERVER_NAME, the ServerName option for Apache. Set this to the external address.
* HTTPD_SERVER_ADMIN, the mail address to the administrator for server-generated pages.
* HTTPD_SSL, set this to use SSL and listen on port 443. If not set the server listens on port 80.
* SVN_REPO_NAME, the name of a repository to create on startup.
* SVN_USER, the name of a Subversion user to create on startup.
* SVN_PASSWORD, the password for SVN_USER.

The Subversion user will not be created if the svn-users file already exists. Likewise the repository will
not be recreated if it exists.

## Notes

* It is important to set the ServerName option to the real external host name, as Subversion (or rather DAV) needs it for the copy command.
  Set HTTPD_SERVER_NAME when using the default configuration or be sure to set it manually. If not defined the container's host name will
  be used and that is probably wrong.
* It is a very good idea to require SSL/TLS or alternatively to use a web front with SSL.

Suggestions and pull requests are welcome!
