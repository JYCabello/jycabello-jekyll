## Yeray Cabello's blog

To run in locally, install ruby 3.1.2 and bundler with `gem install bundler`, then go to the project folder and do:
```bash
bundle install #only once
bundle exec jekyll serve --watch --force_polling
```

To rebundle the css:
Install node, npm and gulp, then go to the project folder and:
```bash
npm i
gulp build
```