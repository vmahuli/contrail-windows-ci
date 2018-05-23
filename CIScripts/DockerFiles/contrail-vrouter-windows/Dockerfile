# escape=`
FROM microsoft/nanoserver

COPY Artifacts.zip C:\
VOLUME C:\Artifacts

# Sets a command or process that will run each time a container is run from the new image.
CMD powershell -Command `
    Expand-Archive -Force -Path C:\Artifacts.zip -DestinationPath C:\Artifacts\
