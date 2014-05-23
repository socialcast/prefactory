[![Build Status](https://secure.travis-ci.org/socialcast/prefactory.png?branch=master)](http://travis-ci.org/socialcast/prefactory)

# Prefactory

The ease and fidelity of factories with the performance of static fixtures.

Prefactory allows you to create factory objects and perform other
expensive ActiveRecord operations in RSpec before(:all) blocks, transparently
wrapping example groups in nested transactions to automatically roll back
any data changes that occur during a specific test, while also ensuring
after-commit callbacks are executed for the synthetic commits.

## Requirements

* ActiveRecord >= 4
* RSpec
* FactoryGirl
* A database for which ActiveRecord supports [nested transactions](http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions) (e.g. MySQL, Postgresql)

## Installation

Add the gem to the :test group in your Rails application's Gemfile:

```  ruby
group :test do
  gem 'prefactory'
end
```

Add this to your RSpec `spec_helper.rb`

``` ruby
RSpec.configure do |config|
  config.include Prefactory

  # ensure Rails' transaction fixtures are disabled
  config.use_transactional_fixtures = false

  # optional, to enable shorthand creation
  # using only Factory name (see examples, below)
  config.include FactoryGirl::Syntax::Methods
end
```

## Example

``` ruby
describe User do
  before :all do   # executes once

    # invokes FactoryGirl.create(:user)
    # reference object as 'friend' in tests
    prefactory_add(:friend) { FactoryGirl.create :user }

    # invokes create(:user) if available, e.g
    # if rspec is configured with:
    #   config.include FactoryGirl::Syntax::Methods
    # reference object as 'user' in examples
    prefactory_add :user

  end

  # convenience method, equivalent to:
  # before(:all) do
  #   prefactory_add(:other_friend) do
  #     create :user
  #   end
  # end
  set!(:other_friend) { create :user }

  context 'a new user has no friends' do

    it { user.friends.count.should == 0 }

    context 'with a friend' do
      before(:all) { user.add_friend(friend) }   # executes once

      it { user.friends.count.should == 1 }

      # these changes will be transparently rolled back
      it "allows removing the friend" do
        expect { user.remove_friend(friend) }.to_not raise_error
        user.friends.count.should == 0
      end

      it "disallows adding the same friend again" do
        expect { user.add_friend(friend) }.to raise_error
        user.friends.count.should == 1
      end

      # these changes will be transparently rolled back
      it "allows adding a different friend" do
        expect { user.add_friend(other_friend) }.to_not raise_error
        user.friends.count.should == 2
      end

      it { user.friends.should include friend }
      it { user.friends.should_not include other_friend }
    end
  end
end
```

## Contributing

1. Fork it ( http://github.com/socialcast/prefactory/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a pull request

## Copyright

Copyright (c) 2012-2014 VMware, Inc. All Rights Reserved.
Released under the terms of the MIT license. See LICENSE for details.
