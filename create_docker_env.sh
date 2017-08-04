erb -T - -r $1 $2/Dockerfile.erb > Dockerfile
erb -T - -r $1 $2/build_rpm.sh.erb > build_rpm.sh
chmod +x build_rpm.sh
