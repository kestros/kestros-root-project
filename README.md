# Kestros Root Project
Base Kestros project build manager. Contains dependency and plugin versions for building and installing Bundles and Packages to Kestros or Sling instances.

  * [Usage](#usage)
  * [Project Installation](#project-installation)
    + [Build and Install Bundle](#build-and-install-bundle)
    + [Overriding Destination](#overriding-destination)
      - [Maven Command](#maven-command)
      - [Maven Profile](#maven-profile)
  * [Features](#features)
    + [Enforcer](#enforcer)
    + [kestros-parent-strict Only](#kestros-parent-strict-only)
      - [Checkstyle](#checkstyle)
      - [Findbugs](#findbugs)
      - [Rat](#rat)
      - [Mutation Testing](#mutation-testing)

## Usage
To use the Kestros pom configuration, reference either `kestros-parent` or `kestros-parent-strict` as the parent.

```
  <parent>
    <groupId>io.kestros.commons</groupId>
    <artifactId>kestros-parent</artifactId>
    <version>0.0.5</version>
    <relativePath/>
  </parent>
```
`kestros-parent` is the baseline model, containing all of the dependency versions and build profiles for installing bundles and packages to Kestros/Sling.

```
  <parent>
    <groupId>io.kestros.commons</groupId>
    <artifactId>kestros-parent-strict</artifactId>
    <version>0.0.5</version>
    <relativePath/>
  </parent>
```
`kestros-parent-strict` is an extension of `kestros-parent`, but includes configurations for plugins that can break the build when code quality issues are detected (maven-checkstyle-plugin, maven-findbugs-plugin, maven-rat-plugin). 

## Project Installation
### Build and Install Bundle
For `bundle` modules, include the following:

```
<plugin>
    <groupId>org.apache.felix</groupId>
    <artifactId>maven-bundle-plugin</artifactId>
    <extensions>true</extensions>
    <configuration>
        <instructions>
            <Export-Package>com.my.package.*</Export-Package>
            <Sling-Model-Packages>
                com.my.package
            </Sling-Model-Packages>
        </instructions>
    </configuration>
</plugin> 
```
When building, use `-P,installBundle` to install the Bundle to your Sling instance.

### Overriding Destination

#### Maven Command
`mvn clean install -Dsling.host=<host> -Dsling.port=<port> -Dsling.user=<username> -Dsling.password=<password> -P,installBundle`

#### Maven Profile
```
<profiles>
  <profile>
      <id>my-environment</id>
      <properties>
          <sling.host>http://localhost</sling.user>
          <sling.port>8080</sling.port>
          <sling.user>username</sling.user>
          <sling.password>password</sling.password>
      </properties>
  </profile>
</profiles>
```  

## Features

### Enforcer
Both `kestros-parent` and `kestros-parent-strict` use the `maven-enforcer-plugin` to enforce Java, Maven, and Sling versions during the build, as well as ban some plugins from being used.

Banned plugins include:
 * `org.apache.felix:maven-scr-plugin` - Felix SCR annotations and the maven-scr-plugin are no longer supported - please migrate to OSGi.
 * `org.apache.felix:org.apache.felix.scr.annotations` - Felix SCR annotations and the maven-scr-plugin are no longer supported - please migrate to OSGi.
 * `org.apache.sling:maven-sling-plugin` - Please change all occurrences of maven-sling-plugin to sling-maven-plugin (plugin was renamed).
 
 To skip the enforcer configuration, use `-Denforcer.skip`.
 
### kestros-parent-strict Only 
#### Checkstyle
The `kestros-parent-strict` pom uses a [custom Checkstyle configuration] (https://github.com/kestros/kestros-root-project/blob//build-tools/src/main/resources/checkstyle.xml) Google's Java checkstyle configuration, with minor overrides for mandating full javadoc coverage on public classes and methods.
For more information, see the [Google's Java Style Guide] (https://google.github.io/styleguide/javaguide.html).
[google_checks.xml] (https://github.com/checkstyle/checkstyle/blob/master/src/main/resources/google_checks.xml)



To skip use `-Dcheckstyle.skip`.
#### Findbugs
`maven-findbugs-plugin` is used to check for bug patterns in Java code and will fail the build when any are detected.  `@SuppressFBWarnings("<<ERROR_NAME>>")` can be used to suppress false positives, or `-Dfindbugs.skip` to skip.

#### Rat
`apache-rat-plugin` is used to enforce the licensing of all files within a project.  To skip use `-Drat.skip`.

#### Mutation Testing
To run mutation testing using built in configuration, use the `mutationTest` build profile.