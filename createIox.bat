REM docker push robraesemann/foglamp-dnp3-dev:1.9.0
docker save -o IOx\rootfs.tar robraesemann/foglamp-dnp3-dev:1.9.0
cd IOx
ioxclient.exe package .
rename package.tar foglamp-dnp3-dev_1.9.0.tar
del rootfs.tar