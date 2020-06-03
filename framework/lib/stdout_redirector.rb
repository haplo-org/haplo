# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class StdoutRedirector
  DUMMY_WRITE_PROC = proc {|*args|}

  def initialize(io)
    @io = io
    @write_proc = DUMMY_WRITE_PROC
  end

  def write_proc=(proc)
    @write_proc = proc
  end

  def write_proc
    Thread.current[:_stdout_rdr_write_proc] || @write_proc
  end

  def with_alternative_write_proc_in_thread(proc)
    old_write_proc = Thread.current[:_stdout_rdr_write_proc]
    Thread.current[:_stdout_rdr_write_proc] = proc
    yield
  ensure
    Thread.current[:_stdout_rdr_write_proc] = old_write_proc
  end

  def method_missing(sym, *args, &block)
    @io.send sym, *args, &block
  end

  def write(*args)
    @io.send :write, *args
    write_proc.call(args.join(''))
  end

  def print(*args)
    @io.send :print, *args
    write_proc.call(args.map { |a| a.to_s }.join(''))
  end

  def printf(*args)
    @io.send :printf, *args
    write_proc.call(sprintf(*args))
  end

  def puts(*args)
    @io.send :puts, *args
    lines = args.map { |a| a.to_s }.join("\n")
    lines << "\n"
    write_proc.call(lines)
  end
end
