ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # 並列実行はしない。Ruby 4.0.7 + trilogy 2.13.1 では、スレッド並列にすると
    # 「This connection is already in use by another thread or fiber」で大量に失敗するため。
    # 件数が少なく、並列なしでも十分速い(77件で約9秒)。
    # parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
