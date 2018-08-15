## How to release to the XING internal gem storage
1. Bump the version in `version.rb`
2. Run `bundle exec rake install`
3. Run `gem sources -a https://gems.xing.com/`
4. Run `gem inabox -g https://gems.xing.com/`
