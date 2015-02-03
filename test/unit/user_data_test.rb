# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserDataTest < Test::Unit::TestCase

  def setup
    db_reset_test_data
  end

  # Allocate some names for the testing
  TESTNAME_STRING_USER = UserData.allocate_name(900, :user_level)
  TESTNAME_STRING_INHERIT = UserData.allocate_name(901, :inheritable)
  TESTNAME_BOOL = UserData.allocate_name(904, :user_level, UserData::BOOLEAN_READER)  # Note ordering of int name
  TESTNAME_INT = UserData.allocate_name(903, :inheritable, UserData::INT_READER)      # Note ordering of int nmae
  TESTNAME_STRING_INHERIT2 = UserData.allocate_name(905, :inheritable)

  def test_user_data
    # Check the names have right values
    assert_equal 900, TESTNAME_STRING_USER
    assert_equal 901, TESTNAME_STRING_INHERIT
    assert_equal 903, TESTNAME_INT
    assert_equal 904, TESTNAME_BOOL

    # Check it's not possible to reallocate names
    assert_raises(RuntimeError) do
      UserData.allocate_name(TESTNAME_STRING_USER, :inheritable)
    end

    # Check that the fixtures have the right constants
    assert_equal User::KIND_USER, User.find(41).kind
    assert_equal User::KIND_GROUP, User.find(21).kind
    assert_equal 'ANONYMOUS', User.find(User::USER_ANONYMOUS).name
    assert_equal 'Everyone', User.find(User::GROUP_EVERYONE).name
    assert_equal 'Administrators', User.find(User::GROUP_ADMINISTRATORS).name

    # Check that membership IDs are returned in the right order
    # The groups 'closest' to the group are returned first
    assert_equal [16,21,4], User.find(41).groups_ids
    assert_equal [22,4], User.find(42).groups_ids
    assert_equal [21,22], User.find(23).groups_ids    # doesn't have GROUP_EVERYONE added because it's a group
    assert_equal [21,22], User.find(23).direct_groups_ids
    assert_equal [16,23,21,22,4], User.find(43).groups_ids
    assert_equal [16,23], User.find(43).direct_groups_ids

    # Simple set, retrieve, update
    assert_equal nil, UserData.get(41,TESTNAME_STRING_USER)
    UserData.set(41,TESTNAME_STRING_USER,'pants')
    assert_equal 'pants', UserData.get(41,TESTNAME_STRING_USER)
    UserData.set(41,TESTNAME_STRING_USER,'trousers')
    assert_equal 'trousers', UserData.get(41,TESTNAME_STRING_USER)
    # check it doesn't affect other users
    assert_equal nil, UserData.get(42,TESTNAME_STRING_USER)
    # and delete
    UserData.delete(41,TESTNAME_STRING_USER)
    assert_equal nil, UserData.get(41,TESTNAME_STRING_USER)

    # Test storing int and bool values
    UserData.set(42,TESTNAME_BOOL,true)
    assert_equal TrueClass, UserData.get(42,TESTNAME_BOOL).class
    UserData.set(42,TESTNAME_BOOL,false)
    assert_equal FalseClass, UserData.get(42,TESTNAME_BOOL).class
    UserData.set(42,TESTNAME_INT,12)
    assert_equal Fixnum, UserData.get(42,TESTNAME_INT).class
    assert_equal 12, UserData.get(42,TESTNAME_INT)

    # Basic test for inheritable values
    # -- inherited data
    UserData.set(22,TESTNAME_STRING_INHERIT,'h1')
    assert_equal 'h1', UserData.get(42,TESTNAME_STRING_INHERIT)
    # -- non-inherited data
    UserData.set(22,TESTNAME_STRING_USER,'h2')
    assert_equal nil, UserData.get(42,TESTNAME_STRING_USER)

    # Check with alternative access methods
    user42 = User.find(42)
    assert_equal 'h1', UserData.get(user42,TESTNAME_STRING_INHERIT)
    assert_equal nil, UserData.get(user42,TESTNAME_STRING_USER)
    assert_equal 'h1', user42.get_user_data(TESTNAME_STRING_INHERIT)
    assert_equal nil, user42.get_user_data(TESTNAME_STRING_USER)

    # Check setting with shortcust
    user42.set_user_data(TESTNAME_STRING_USER,'xxx1')
    assert_equal 'xxx1',user42.get_user_data(TESTNAME_STRING_USER)
    assert_equal 'xxx1',UserData.get(42,TESTNAME_STRING_USER)
    user42.delete_user_data(TESTNAME_STRING_USER)
    assert_equal nil,user42.get_user_data(TESTNAME_STRING_USER)
    assert_equal nil,UserData.get(42,TESTNAME_STRING_USER)

    # More complicated tests: chain of inherited data, with alternative access methods
    user43 = User.find(43)
    UserData.set(4,TESTNAME_STRING_INHERIT2,'h3')
    assert_equal 'h3', UserData.get(43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h3', UserData.get(user43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h3', user43.get_user_data(TESTNAME_STRING_INHERIT2)
    UserData.set(22,TESTNAME_STRING_INHERIT2,'h4')
    assert_equal 'h4', UserData.get(43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h4', UserData.get(user43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h4', user43.get_user_data(TESTNAME_STRING_INHERIT2)
    UserData.set(21,TESTNAME_STRING_INHERIT2,'h5')
    assert_equal 'h5', UserData.get(43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h5', UserData.get(user43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h5', user43.get_user_data(TESTNAME_STRING_INHERIT2)
    UserData.delete(21,TESTNAME_STRING_INHERIT2)
    assert_equal 'h4', UserData.get(43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h4', UserData.get(user43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h4', user43.get_user_data(TESTNAME_STRING_INHERIT2)
    UserData.delete(22,TESTNAME_STRING_INHERIT2)
    assert_equal 'h3', UserData.get(43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h3', UserData.get(user43,TESTNAME_STRING_INHERIT2)
    assert_equal 'h3', user43.get_user_data(TESTNAME_STRING_INHERIT2)

    # Check case where there's no groups to follow
    assert_equal nil, UserData.get(User::GROUP_EVERYONE, TESTNAME_STRING_INHERIT)

    # Check delete doesn't break other things
    assert_equal nil, UserData.get(42,TESTNAME_STRING_USER)
    UserData.set(42,TESTNAME_STRING_USER,'x')
    UserData.set(42,TESTNAME_INT,8)
    UserData.set(43,TESTNAME_INT,9)   # another user
    assert_equal 'x', UserData.get(42,TESTNAME_STRING_USER)
    assert_equal 8, UserData.get(42,TESTNAME_INT)
    assert_equal 9, UserData.get(43,TESTNAME_INT)
    UserData.delete(42,TESTNAME_STRING_USER)
    assert_equal nil, UserData.get(42,TESTNAME_STRING_USER)
    assert_equal 8, UserData.get(42,TESTNAME_INT)
    assert_equal 9, UserData.get(43,TESTNAME_INT)
  end
end
