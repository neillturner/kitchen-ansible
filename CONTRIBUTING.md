# How to contribute

For now, there's not much guidance for new contributors. If you encounter an issue whilst trying to contribute, please document the issue and how to fix it in this file.

# Getting started

To contribute, you need to install the project's dependencies. You can install all dependencies for kitchen-ansible via Bundler. To do so, run the following (this will install dependencies local to the project):

```
bundle install --path vendor/bundle
```

# Running the tests

kitchen-ansible ships with a set of unit tests. When contributing, please run the tests before making any changes, and ensure that they all pass after your changes. Any additions to the code should be covered by a relevant unit test

To run all tests, run `bundle exec rake test`
