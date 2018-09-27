# Unofficial Docker Images for Adobe Coldfusion 11

## Images

* Adobe Coldfusion 11 Hotfix 15 (no add-ons): [Docker Hub](https://hub.docker.com/r/inleague/coldfusion11) (:latest / :hf15)
* PDFG Add-on (standalone): [Docker Hub](https://hub.docker.com/r/inleague/coldfusion_pdfg) (:acf11 / :latest)

## Environment variables

* cfconfigfile: The full path to a cfconfig JSON file to be applied prior to starting the server.

## JVM / Memory Usage

The JVM config uses two options designed for containers (**-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap**) rather than fixed heap sizes. By default, they will use all of the memory and CPU allocated to the container. This has not been tested specifically for CF in a production environment. This section will be updated as we discover or get reports on real-world usage.

## Document Root / Reverse Proxy Setup

This image is somewhat prescriptive in how it expects incoming requests to the CF engine. There are two connectors defined in Tomcat's **server.xml**:

* (Port 8500) The standard HTTP Tomcat connector (aka Coldfusion's "internal webserver")
* (Port 8014) The standard AJP Tomcat connector

In a containerized deployment, a reverse proxy to port 8500 is likely to be much easier to work with than AJP connectors.

The document root (configured in **server.xml**) is the **/var/www** directory, with a virtual aliases for **/CFIDE** and **/WEB-INF**.  The [mod_cfml](https://viviotech.github.io/mod_cfml/index.html) valve is also configured to dynamically generate web contexts based on the **X-Tomcat-DocRoot** header. 

These connectors and mod_cfml can be reconfigured by replacing the server.xml, either as part of deployment or in extending the image.

## How To Use This Image or Build Your Own

This image exposes the CF engine on port 8500 via HTTP. It is designed to be use with a reverse proxy rather than an AJP connector, but the images could easily be re-built 

While [Commandbox](https://hub.docker.com/r/ortussolutions/commandbox/) is the preferred method for deploying any CF engine (in development) and Enterprise- or Lucee engines (in Production), Adobe Coldfusion 11 (Standard) doesn't have a Docker-friendly means of deployment. Running ACF11 in any kind of modern DevOps environment is not ideal and you'll be better served using a more recent CF engine (whether Lucee or Adobe CF 2018), but we had a transition period in our shop where we wanted everything in Docker prior to being ready to upgrade ourselves, and this is the result of that labor. 

**These images are not provided by or supported by Adobe**. They use the standard Adobe installer, but some of the stock files (particularly **jvm.config**) are overwritten with more Docker-friendly versions. Installers and hotfixes used in this build process are mirrors of Adobe's but they are not pulled from Adobe directly, so if your security policy requires that you get these things from official vendor channels ... you probably shouldn't be here anyway!

The image is based on Ubuntu (Bionic) 18.04 LTS. **You will likely be best served by downloading this repo and editing the Dockerfile based on your own needs**, particularly with respect to the installer properties and add-on services. 

The build process performs the following operations:

1) Installs libstdc++5, nano, curl, and OpenJDK 8
2) Installs the current stable version of Commandbox so we can use CFConfig
3) Download the Adobe installer from the unofficial CFML Repo
4) Run the Adobe installer silently, using properties defined in **silent.properties** (e.g. add-ons, secure profile, allowed IPs)
5) Download the latest hotfix (currently 15) and apply it

When the container starts, a script checks for the presence of a **$cfconfigfile** environment variable, and if it finds one that resolves to a valid path, it will apply it to the server prior to starting the server. 

The base image does not install add-on services like the PDF service or SOLR. The PDF service has a large number of dependencies and these images are quite large already. We maintain a separate image (and github) for the PDF service; it can be run in a separate container and serve multiple CF servers.

## Customization 

Almost everything can be configured via CFConfig and those directives should be mounted at runtime as configs (for **docker stack**) or secrets (for **docker-compose**). If you want to change the add-on services or other ACF install-time options, edit **silent.properties** and rebuild the image. 

## PDFG add-on

The Coldfusion container does not include a local PDF service. It can be built to include one by customizing silent.properties (above), but if you want to deploy a separate PDFG container, you can add it to your CF Admin through the Admin API. Suppose we had an environment variable called $cfconfig_adminPassword that contained our credentials for CF Admin. We could initialize our app as follows to connect to a container called **pdfg**:

```
	var adminMgr = new CFIDE.adminapi.Administrator();
		var system= createObject( "java", "java.lang.System" );
		var cfAdminPw = system.getENV("cfconfig_adminPassword");
		adminMgr.login(cfAdminPw);
		
		dAPI = new CFIDE.adminapi.document();
		var managers = dAPI.getAllServiceManager();

		if (!structKeyExists(managers,'pdfg')) {
			dAPI.disableServiceManager("localhost");
			dAPI.addServiceManager(name='pdfg',hostname='pdfg',port=8987,weight=3,ishttps=false);
		}
```
Note that the PDFG service checks the licensing of the server registering the connection at the time it is registered; if you do not have license information in your CFConfig file when starting your CF container, the PDFG service will watermark everything with the Developer Edition.

The PDFG container will accept connections from anywhere that can reach it. This can be customized in the Jetty files but is more easily managed through Docker (i.e. don't publish any ports and just have your CF containers on the same network).

## Known Issues

* Container stop / SIGHUP: The Coldfusion service is stopped as if the entire system were coming down; it is not stopped via **coldfusion stop** or **cfstop.sh**. Feel free to submit a PR to support this.
