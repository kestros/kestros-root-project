# Kestros Root Project
Base Kestros project build manager. Contains dependency and plugin versions for building and installing Bundles and Packages to Kestros or Sling instances.

## Usage
To use the Kestros pom configuration, reference either `kestros-parent` or `kestros-parent-strict` as the parent.

```
  <parent>
    <groupId>io.kestros.commons</groupId>
    <artifactId>kestros-parent</artifactId>
    <version>0.0.2-SNAPSHOT</version>
    <relativePath/>
  </parent>
```
`kestros-parent` is the baseline model, containing all of the dependency versions and build profiles for installing bundles and packages to Kestros/Sling.

```
  <parent>
    <groupId>io.kestros.commons</groupId>
    <artifactId>kestros-parent-strict</artifactId>
    <version>0.0.2-SNAPSHOT</version>
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

### Maven Profile
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
To use the built in maven-enforcer-plugin configuration, , include the following in the `<build>` `<plugins>`
```
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-enforcer-plugin</artifactId>
</plugin>
```
The built in configuration will fail builds with that are compiled with invalid java version, and bundles using deprecated dependencies.
### Checkstyle
To use the built in checkstyle configuration, include the following in the `<build>` `<plugins>`:
```
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
</plugin>
```
This project uses Google's Java checkstyle. For more information, read the [Google's Java Style Guide] (https://google.github.io/styleguide/javaguide.html).
[google_checks.xml] (https://github.com/checkstyle/checkstyle/blob/master/src/main/resources/google_checks.xml)
### Findbugs
To use the built in findbugs configuration, include the following in the `<build>` `<plugins>`: 
```
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>findbugs-maven-plugin</artifactId>
</plugin>

```

### Mutation Testing
To run mutation testing using built in configuration, use the `mutationTest` build profile.