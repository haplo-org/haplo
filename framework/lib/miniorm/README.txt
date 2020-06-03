
MiniORM is a minimal Ruby ORM which prioritises security over all else. It is
designed solely for Haplo, and is unlikely to be usable in any other project.
As all the main application development happens above the plugin API, the
platform is not intended to move fast, so MiniORM does not have to be flexible
or need to minimise verbosity.

These design criteria allow the ORM to have an absolutely minimal feature set,
reducing the attack surface. Features which have been omitted include:

- Multiple property assignment from dictionary-like objects, preventing
  accidents when accepting data from untrusted sources.

- Use of SQL in queries built at runtime, preventing SQL injection attacks.

- Validation of the data in the record objects, leaving it to the database to
  reject bad data.

- Automatic database schema management and "Don't Repeat Yourself" definition
  of database tables.

- Joins between tables.

- Selection of a subset of columns in queries.

- Automatic conversion of values specified when assigning properties.

In MiniORM, all query clauses and orderings much be specified upfront when the
table's Ruby class is defined. Because SQL cannot be provided at query time,
this forces all SQL generation to use parameters which are inserted safely by
the JDBC driver. Similarly, specifying all orders up-front means you can't
accidentally inject SQL by taking the ordering from untrusted sources. Because
all these query clauses and orders have names which are reflected in the names
of automatically generated methods on the Ruby objects, it results in very
readable queries.

Unfortunately, there are also 'unsafe' query and order clauses which allows
arbitrary SQL to be injected at runtime, but so far is only used once.
Hopefully the names unsafe_where_sql() and unsafe_order() will discourage any
further use.

Multiple assignment is moved out of the record object into separate Transfer
objects. These specify the properties to be taken from untrusted input and any
validation rules. If the validation passes, the data is 'transfered' into the
record object. While this is more verbose than providing multiple assignment,
accidents are prevented by stating explicitly what data is to be used from the
untrusted source, and what it should look like.
