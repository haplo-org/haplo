/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.miniorm;

import org.joda.time.DateTime;
import java.sql.Timestamp;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Array;
import java.sql.SQLException;
import org.jruby.RubyTime;
import org.jruby.runtime.builtin.IRubyObject;

public class Values {

    public static void setSQLTimestampFromRubyTime(PreparedStatement statement, int index, IRubyObject value) throws SQLException {
        if(!(value instanceof RubyTime)) {
            throw new RuntimeException("Value is not a Ruby Time object");
        }
        RubyTime timeValue = (RubyTime)value;
        DateTime dateTime = timeValue.getDateTime();
        Timestamp timestamp = new Timestamp(dateTime.getMillis());
        if(timeValue.getNSec() > 0) {
            timestamp.setNanos((int)(timestamp.getNanos() + timeValue.getNSec()));
        }
        statement.setTimestamp(index, timestamp);
    }

    public static boolean setRubyTimeFromSQLTimestampValue(ResultSet results, int index, IRubyObject valueOut) throws SQLException {
        Timestamp timestamp = results.getTimestamp(index);
        if(results.wasNull()) { return false; }
        RubyTime timeValue = (RubyTime)valueOut;
        timeValue.setDateTime(new DateTime(timestamp.getTime()));
        timeValue.setNSec(timestamp.getNanos() % 1000000);
        return true;
    }

    // ----------------------------------------------------------------------

    public static void setIntArray(PreparedStatement statement, int index, Integer[] array) throws SQLException {
        statement.setArray(index, statement.getConnection().createArrayOf("int4", array));
    }

    public static Object getIntArray(ResultSet results, int index) throws SQLException {
        Array arr = results.getArray(index);
        if(results.wasNull()) { return null; }
        return results.getArray(index).getArray();
    }

    // ----------------------------------------------------------------------

    public static void setTextArray(PreparedStatement statement, int index, String[] array) throws SQLException {
        statement.setArray(index, statement.getConnection().createArrayOf("text", array));
    }

    public static Object getTextArray(ResultSet results, int index) throws SQLException {
        Array arr = results.getArray(index);
        if(results.wasNull()) { return null; }
        return results.getArray(index).getArray();
    }

}
