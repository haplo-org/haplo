/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.metrics.prometheus.PrometheusMetricsTrackerFactory;
import org.postgresql.ds.PGSimpleDataSource;

import org.apache.log4j.Logger;

import java.util.Properties;
import java.sql.Connection;
import java.sql.Statement;


public class Database {
    private static Properties configProperties;
    private static HikariDataSource ds;
    private static PGSimpleDataSource dsLongRunning;
    private static ThreadLocal<Connection> connection = new ThreadLocal<Connection>();

    public static void configure(String server, String database, String username, String password) {
        // Pooled data connection
        Properties p = new Properties();
        p.setProperty("dataSourceClassName", "org.postgresql.ds.PGSimpleDataSource");
        p.setProperty("dataSource.serverName", server);
        p.setProperty("dataSource.databaseName", database);
        p.setProperty("dataSource.user", username);
        if(password != null) { p.setProperty("dataSource.password", password); }
        // Set size of pool to avoid using too many connection when reltively idle, but scale up under load
        p.setProperty("minimumIdle", "8");
        p.setProperty("maximumPoolSize", "92");
        configProperties = p;

        // Long-running connections aren't in the pool
        dsLongRunning = new PGSimpleDataSource();
        dsLongRunning.setServerName(server);
        dsLongRunning.setDatabaseName(database);
        dsLongRunning.setUser(username);
        if(password != null) { dsLongRunning.setPassword(password); }
    }

    public static void start() {
        HikariConfig config = new HikariConfig(configProperties);
        HikariDataSource source = new HikariDataSource(config);
        ds = source;
    }

    public interface UseConnection {
        public Object use(Connection connection) throws java.sql.SQLException;
    }

    public static Object withConnection(UseConnection usage) throws java.sql.SQLException {
        // Allow reentrancy
        Connection c = connection.get();
        if(c != null) {
            return usage.use(c);
        }
        // Make a new connection and close after use
        c = ds.getConnection();
        try {
            connection.set(c);
            return usage.use(c);
        } catch(Exception e) {
            // Clean up connection if an exception reaches the level
            // in the stack where the connection was opened.
            try {
                execute(c, "ROLLBACK");
                execute(c, "SET search_path TO public");
                Logger.getLogger("org.haplo.database").
                    error("ROLLBACK database connection after exception", e);
            } catch(Exception x) {
                ds.evictConnection(c);
                Logger logger = Logger.getLogger("org.haplo.database");
                logger.error("Evicted connection after exception during cleanup ROLLBACK", x);
                logger.error("Original exception was ", e);
            }
            throw e;
        } finally {
            connection.set(null);
            c.close();
        }
    }

    public static void execute(Connection connection, String sql) throws java.sql.SQLException {
        try(Statement statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }

    public static void collectMetrics() {
        if(ds != null) {
            ds.setMetricsTrackerFactory(new PrometheusMetricsTrackerFactory());
        }
    }
}
