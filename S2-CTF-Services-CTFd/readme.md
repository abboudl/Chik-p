# CTF Services: CTFd

## Purpose
CTFd is a popular Capture the Flag (CTF) platform. It acts as a scoreboard, a challenge server, as well as a flag submission and player registration portal. 

CTFd is a multi-tiered solution consisting of three services:
- A Flask project delivered via a Gunicorn application server
- A MariaDB MySQL database
- A Redis cache

This repository hosts an instance of CTFd coupled with a Filebeat service to ship logs to ELK. All four services are built into docker images and then deployed using docker-compose and Ansible as part of the automated infrastructure build process. 

## Configuration

For a full configuration and administration guide, see CTFd's official documentation: __________. The remainder of this section will discuss important details relevant to the CTF infrastructure administrator.

### Configuration Files

The CTF infrastructure administrator can configure CTFd using `CTFd/config.ini`. However, it is better to specify configuration parameters under the `environment` key in `docker-compose.yml`. These parameters will be read by CTFd after they have been injected into their respective container as environment variables at runtime.

Some of these configuration parameters, such as `SECRET_KEY` and `MYSQL_PASSWORD` are secrets that should never be committed to a git repository. These secrets are read from a `.env` file in the same directory as `docker-compose.yml`. This `.env` file has been gitignored (i.e. it is not present in this Github repository) and as such must either be:
1. created manually by the CTF infrastructure administrator. A template .env file is provided in `.example-env`.
2. created automatically during the automated infrastructure build process by a configuration manager such as Ansible.

If you wish to run CTFd in standalone mode for testing purposes, option #1 is preferable. Simply rename `.example-env` to `.env`, edit the file, then run `docker-compose up`. 

If you wish to deploy the entire environment, option #2 is preferable. You do not need to do anything. Passwords are pulled from a LastPass vault, injected into a template `.env` file, and then transferred over to the CTFd host. <template file> and <deploy-ctfd.yml> provide a step by step guide on how CTFd is deployed.

Next, we provide a brief description of a few important configuration parameters set in docker-compose.yml file:
- **LOG_FOLDER**: set the CTFd logging folder inside the container which houses CTFd, Gunicorn, and MySQL logs.
- **ACCESS_LOG** and **ERROR LOG**: enables the gunicorn access and error logs. While these logs are enabled, we choose to ship the Nginx logs to ELK as they are closer to the user.
- **WORKERS**: set the number of gunicorn workers to 10 . This value offers great performance for a CTF with 500-800 participants assuming 2vCPUs and a 12GB of RAM.
- **REVERSE PROXY**: tell CTFd that it behind a reverse proxy like Nginx.
- **HTML_SANITIZATION**: turn on HTML sanitization to escape dangerous characters and protect against attacks like XSS.

### CTF Data

Upon launch, CTFd creates a `.data` directory in the project root. Most subdirectories of `.data` are configured as bind mounts (under the `volumes` key in docker-compose. They expose runtime data inside the CTFd, MariaDB, and MySQL containers to the underlying host. Runtime data includes logs, uploads, cached items, etc.

You can use the `.data` directory to conduct a full restore of CTFd in the event of a disaster. As such, it is critical that you create regular backups of this directory. An easy way to do this is to schedule a cron job on the CTFd host that creates a backup of this directory evey 2 minutes or so.

### Logging

Inside the container, logs are stored in `/var/log/`. On the docker host, this directory maps to `.data/logs/`. 

By default, CTFd logs submissions, logins, and registrations in separate files. 

A gunicorn access and error log is also provided. Much like apache and nginx logs, it uses the standard "combined" logging format.

### Filebeat Sidecar Container

A Filebeat container is used to ship logs to logstash for processing. To customize filebeat's configuration, edit `filebeat/filebeat.yml`.  Only logs in files matching the following patterns are shipped.
- logins.log*
- registrations.log*
- submissions.log*

The * accounts for lot rotation. (`logins.log`, `logins.log.1`, `logins.log.2`, etc.).

Unfortunately, CTFd logs do not come in a standardized format such as CSV or JSON but are closer to print statements. In previous competitions, CTFd logging was altered to fit a schema and a logstash parser was written to parse the data into fields. We strongly recommend you do the same. At the moment, you will see unprocessed CTFd logs in Kibana under the following index patterns:
- ctf-logins-*
- ctf-registrations-*
- ctf-submissions-*

### Rate Limiting

By default, CTFd limits flag submissions to 10 per minute per team. 

## Deployment

See <template file> and <deploy-ctfd.yml> in <> to form an understanding of how CTFd is deployed.

### Network Location

Internal Subnet.

### Important Accounts, Credentials, and Secrets

During service deployment, Ansible uses the `lpass` commandline utility to retrieve passwords from a LastPass password vault. The following tables catalog all secrets related to CTFd that must be set up in lastpass prior to the <automated infrastructure build process>.

| LastPass ID                     | Secret Type              | Username            | Description                                                                                              | 
|---------------------------------|--------------------------|---------------------|----------------------------------------------------------------------------------------------------------|
| ctf_ctfd_secret_key             | 64-Character Secret Key  | ctf_ctfd_secret_key | Used by the CTFd Flask application to sign session cookies for protection against cookie data tampering. |
| ctf_mysql_account               | 16+ Character Password                 | *pick-a-username*   | Username and password are set by the CTF Infrastructure Administrator. This account is used by CTFd's object relational mapper (ORM) to populate the ctfd database. It can also be used by the CTF Administrator to manually manage the Mariadb MySQL database if needed.|
| ctf_mysql_root_pass             | 16+ Character Password                 | root                | Root password to the MySQL DBMS. Username is "root".                                                     |

### Pre-Deployment Configuration Checklist

Before starting the automated infrastructue build process, please perform the following steps:
1. Generate secrets related to CTFd and store them in a LastPass password vault (See "Important Accounts, Credentials, and Secrets" above.)
2. Point filebeat to the logstash host by editing `filebeat.yml` with logstash's FQDN and port number under the `output.logstash` key.
2. Review docker-compose.yml and verify that all configuration parameters are correct.
4. (Optional) Add a captcha to the registration form. A plugin, CTFd Captcha Plugin, already exists.
5. (Optional) Standardize CTFd's logs and write a logstash parser that can process them into elasticsearch documents.

### Post-Deployment Configuration Checklist

Once the automated infrastructure build process is complete, there are a number of steps that need to be taken to prepare CTFd for game day.

1. Add a mail server so that CTFd can send password reset and registration confirmation emails. Then enable "Verify User Emails". You can do this using the admin panel.
2. Configure scoreboard visibility, challenge visibility, and registration visibility settings in the admin panel. 
3. Customize CTFd's look and feel using the CSS editor in the admin panel.
4. Set competition time and # of players per team.
5. Add a privacy policy and a terms of service.
6. Practice performing a backup and restore operation using the admin panel.
7. Schedule a cron job to backup the .data directory.


## Maintenance

Every once in a while, a new version of CTFd is released packed with new features and bug fixes. It is the duty of the CTF Infrastructure Administrator to update CTFd in a timely fashion. CTFd, much like any other popular piece of software, receives a number of CVEs and so applying patches quickly is critical. 

### How to update CTFd?

The only differences between vanilla CTFd and this fork are:
- A modified docker-compose file
- A modified Dockerfile
- The addition of the filebeat directory

These changes should be fairly easy to replicate to the new version.

It becomes difficult to update CTFd, however, if the forked version's code has been modified (for example, to include a new logging module). The patching process may become tedious. As such, it is recommended that changes to the codebase are kept minor and easily repeatable. It is better to fix problems at the source by submitting a feature request or even a pull request to CTFd.
