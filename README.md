# RspecHasPrefactory

The ease of factories, the performance of fixtures.

RspecHasPrefactory builds your Factory object graph before the start of
the suite due to rspec's before :all, and then any data changes that
occur during a specific test are automatically rolled back.

## Installation

Add this line to your application's Gemfile:

``` 
gem 'prefactory'
```

Add this to your `spec_helper.rb`

``` ruby
RSpec.configure do |config|
  config.extend RSpecAroundAll
  config.include RspecHasPrefactory
end
```

## Example

``` ruby
describe User do
  before :all do
    prefactory_add :user
    prefactory_add(:friend) { create :user }
  end
  context 'a new user has no friends' do
    it { user.friends.count.should == 0 }
    context 'after adding friends a user has friends' do
      before { user.add_friend(friend) }
      it { user.friends.count.should == 1 }
    end
  end
end
```

## Contributing

1. Fork it ( http://github.com/socialcast/prefactory/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright (c) 2012-2013 Myron Marston. Released under the terms of the
MIT license. See LICENSE for details.
