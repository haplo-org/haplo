# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# NOTE: Preferred usage for the current user is via @request_user.get_user_data() / @request_user.set_user_data()

class UserData < ActiveRecord::Base
  set_table_name "user_datas" # rules changed, so have to specify the table name
  belongs_to :user

  # ------------------------------------------------------------
  # Name setup function
  @@inherited_reads = Array.new
  @@read_procs = Array.new
  def self.allocate_name(intname, inherit_status, read_proc = nil)
    raise "Name #{intname} already allocated" if @@inherited_reads[intname] != nil
    @@inherited_reads[intname] = (inherit_status == :inheritable)
    @@read_procs[intname] = read_proc
    intname
  end
  BOOLEAN_READER = proc {|v| v == 'true'}
  INT_READER = proc {|v| v.to_i}

  # ------------------------------------------------------------
  # Registry of data names
  NAME_TRAY                   = allocate_name(0, :user_level)   # contents of tray as comma separated objrefs
  NAME_LATEST_EMAIL_FORMAT    = allocate_name(1, :inheritable, INT_READER)  # UserData::Latest::FORMAT_*
  NAME_LATEST_EMAIL_SCHEDULE  = allocate_name(2, :inheritable)  # when:working-days-only:day-of-week:day-of-month
  # NAME_LATEST_FEED_TOKEN      = allocate_name(3, :user_level)   # string token for feed
  # NAME_SVN_DOWNLOAD_METHOD    = allocate_name(4, :inheritable)  # how to handle a click on an SVN file
  NAME_LATEST_UNSUB_TOKEN     = allocate_name(5, :user_level)   # token for one-click unsub in latest updates emails
  NAME_HOME_COUNTRY           = allocate_name(6, :inheritable)  # string of iso code for user's home country, affects localised display
  # NAME_PREFERRED_LANGUAGE     = allocate_name(7, :inheritable) # NOT USED, RESERVED
  NAME_LATEST_EMAIL_TEMPLATE  = allocate_name(8, :inheritable, INT_READER)  # EmailTemplate.id
  NAME_TIME_ZONE              = allocate_name(9, :inheritable)  # string of TZ timezone name for the user, affects localised display

  # JavaScript user data storage
  # TODO: Make JavaScript user data storage a bit nicer, allow inheritable values
  NAME_JAVASCRIPT_JSON        = allocate_name(99, :user_level)

  # ------------------------------------------------------------
  # Get data (may return nil)
  # User can be of class User, User::Info (preferred), Fixnum/Bignum (user ID)
  def self.get(user, name, info_required = :value_only) # or :value_and_uid
    user_id = ((user.kind_of?(Integer)) ? user : user.id)
    ud = UserData.find(:first, :conditions => "user_id=#{user_id} AND data_name=#{name.to_i}")
    # Return it if it's found
    return ((info_required == :value_only) ? ud.value : [ud.value, user_id]) if ud != nil
    # Not found, try inherited
    if @@inherited_reads[name]
      # Need to get a user if just passed an ID
      user = User.cache[user] if user.kind_of?(Integer)
      # Get group membership
      groups = user.groups_ids
      return nil if groups.empty?
      # Find all data
      uds = UserData.find(:all, :conditions => "user_id IN (#{groups.join(',')}) AND data_name=#{name.to_i}")
      # Return the value for the first group in the groups list -- returns the lowest possible name in
      # the heirarchy.
      groups.each do |gid|
        d = uds.find { |ud| ud.user_id == gid }
        return ((info_required == :value_only) ? d.value : [d.value, gid]) if d != nil
      end
    end
    ((info_required == :value_only) ? nil : [nil, nil])
  end

  # ------------------------------------------------------------
  # Set data
  # User can be of class User, User::Info, Fixnum/Bignum (user ID) -- all types are just as good as each other
  def self.set(user, name, value)
    user_id = ((user.kind_of?(Integer)) ? user : user.id)
    db = KApp.get_pg_database
    begin
      db.perform('BEGIN')
      u = db.update('UPDATE user_datas SET data_value=$1 WHERE user_id=$2 AND data_name=$3', value.to_s, user_id, name.to_i)
      if u.cmdtuples() == 0
        # Doesn't exist, add it
        db.update('INSERT INTO user_datas (user_id,data_name,data_value) VALUES($1,$2,$3)', user_id, name.to_i, value.to_s)
      end
      db.perform('COMMIT')
    rescue
      db.perform('ROLLBACK')
      raise
    end
    KNotificationCentre.notify(:user_data, :set, name, user_id, value)
    value
  end

  # ------------------------------------------------------------
  # Delete data
  # User can be of class User, User::Info, Fixnum/Bignum (user ID) -- all types are just as good as each other
  def self.delete(user, name)
    user_id = ((user.kind_of?(Integer)) ? user : user.id)
    UserData.delete_all("user_id=#{user_id} AND data_name=#{name.to_i}")
    KNotificationCentre.notify(:user_data, :delete, name, user_id, nil)
    nil
  end

  # ------------------------------------------------------------
  # Decode value
  def value
    rp = @@read_procs[self.data_name]
    (rp == nil) ? self.data_value : rp.call(self.data_value)
  end
end
