FROM microsoft/iis:windowsservercore-10.0.14393.1358

RUN mkdir C:\TCPTest
RUN echo "<h1>Hello, Contrail!</h1>" > C:\TCPTest\index.html

RUN powershell -NoProfile -Command \
    Import-module IISAdministration; \
    New-IISSite -Name "TCPTest" -PhysicalPath C:\TCPTest -BindingInformation "*:8080:"
    
EXPOSE 8080
