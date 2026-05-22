# The Callable module provides a convenient method to instantiate and call service classes.
# By extending this module, service classes gain a class-level `call` method that forwards
# arguments to the initializer and then invokes the instance-level `call` method.
#
# Usage:
#   1. Extend the `Callable` module in your service class.
#   2. Define an `initialize` method in your service class to accept the necessary arguments.
#   3. Define an instance-level `call` method that implements the service's functionality.
#
# Example:
#   class MyService
#     extend SlackStatusCli::Callable
#
#     def initialize(param1, param2)
#       @param1 = param1
#       @param2 = param2
#     end
#
#     def call
#       # Perform service logic here
#       puts "Called with #{@param1} and #{@param2}"
#     end
#
#     private
#
#     attr_reader :param1, :param2
#   end
#
#   Instead of:
#   MyService.new(param1, param2).call
#
#   You can simply do:
#   MyService.call(param1, param2)
#
# The `call` method can accept any kind of arguments (positional, keyword, etc.)
# and forwards them to the `initialize` method of the service class.
module SlackStatusCli
  module Callable
    # Instantiates the service class and then forwards the arguments to its initialize.
    #
    # Usage:
    #   MyService.call(param1, param2)
    #
    #   This is equivalent to:
    #
    #   MyService.new(param1, param2).call
    def call(...)
      new(...).call
    end
  end
end
