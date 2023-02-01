bundle exec jekyll build
cd ../jycabello.github.io/
git checkout master
rm -r *
cp -rf ../jycabello-jekyll/_site/* .
git add .
git commit -m "Released from local machine"
git push origin master
