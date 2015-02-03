#!/usr/bin/env ruby

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'xapian'
require 'rubygems'
gem 'postgres'
require 'postgres'

DATABASE = File.expand_path(File.dirname(__FILE__)+'/_textidx')

# Make a quick database

x = Xapian::WritableDatabase.new(DATABASE, Xapian::DB_CREATE_OR_OPEN)

x.begin_transaction(true)

[
  [1, %w!pants fish carrot pants!],
  [2, %w!pants something else!],
  [10, %w!else nothing more!]
].each do |docid,terms|
  n = 0
  doc = Xapian::Document.new
  terms.each do |t|
    doc.add_posting(t, n, 1)
    n += 1
  end
  x.replace_document(docid, doc)
end

x.commit_transaction

# Open a database connection

$pgdb = PGconn.new(:dbname => 'khq_development')

$pgdb.exec("SELECT oxp_reset();")
sql = "SELECT oxp_open(0, '#{DATABASE}')"
puts sql
$pgdb.exec(sql)
$pgdb.exec(sql)

qsql = "SELECT oxp_simple_query(0, 'pants', '')"
puts qsql
results = $pgdb.exec(qsql).result
results.each do |r|
  p r
  rx = $pgdb.exec("SELECT oxp_relevancy(#{r[0]})").result
  puts "relevancy: #{rx.first.first}"
  rx.clear
end

# Make lots of databases and open them all, to check oldest is thrown out (look at TRACE statements and verify manually)
0.upto(32) do |i|
  Xapian::WritableDatabase.new(DATABASE+"_#{i}", Xapian::DB_CREATE_OR_OPEN)
end

0.upto(32) do |i|
  sql = "SELECT oxp_open(0, '#{DATABASE}_#{i}')"
  puts sql
  $pgdb.exec(sql)
end
32.downto(0) do |i|
  sql = "SELECT oxp_open(0, '#{DATABASE}_#{i}')"
  puts sql
  $pgdb.exec(sql)
end

