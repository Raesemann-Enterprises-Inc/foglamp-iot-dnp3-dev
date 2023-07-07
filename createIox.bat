REM docker push robraesemann/foglamp-dnp3-dev:1.9.0
docker save -o IOx\rootfs.tar robraesemann/foglamp_dnp3_dev:2.1.0
cd IOx
ioxclient.exe package .
rename package.tar foglamp_dnp3_dev_2.1.0.tar
del rootfs.tar