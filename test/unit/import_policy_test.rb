# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class IdentifierTest < Test::Unit::TestCase

  def test_base_class_policy_violates
    policy = KAppImporter::ImportPolicy.new({}, ["abc.tld"])
    assert_equal false, policy.import_allowed?
    assert_equal ['Policy not implemented'], policy.violations
  end

  # -------------------------------------------------------------------------

  def test_allow_all_policy_allows
    policy = KAppImporter::ImportPolicyAllowAll.new({}, ["abc.tld"])
    assert_equal true, policy.import_allowed?
    assert_equal [], policy.violations
  end

  # -------------------------------------------------------------------------

  def test_policy_generic_violations
    policy = ViolatingPolicy.new({}, ["abc.tld"])
    assert_equal false, policy.import_allowed?
    assert_equal ["Hello","World!"], policy.violations
  end

  class ViolatingPolicy < KAppImporter::ImportPolicy
    def policy
      violation("Hello")
      violation("World!")
    end
  end

  # -------------------------------------------------------------------------

  def test_policy_checks_tasks_ok
    policy = TagCheckingPolicy.new({"serverClassificationTags"=>["ping","pong"]}, ["abc.tld"])
    assert_equal true, policy.import_allowed?
    assert_equal [], policy.violations
  end

  def test_policy_checks_tasks_bad_tag
    policy = TagCheckingPolicy.new({"serverClassificationTags"=>["bad-tag","pong"]}, ["abc.tld"])
    assert_equal false, policy.import_allowed?
    assert_equal ["Source server classification tag 'bad-tag' is not permitted."], policy.violations
  end

  class TagCheckingPolicy < KAppImporter::ImportPolicy
    def policy
      violation_if_server_classification_tag("bad-tag")
    end
  end

  # -------------------------------------------------------------------------

  def test_default_tags_are_not_set
    policy = DefaultTagsPolicy.new({}, "abc.tld")
    assert_equal false, policy.import_allowed?
    assert_equal ["Source server classification tag 'not-set' is not permitted."], policy.violations
  end

  class DefaultTagsPolicy < KAppImporter::ImportPolicy
    def policy
      violation_if_server_classification_tag(KInstallProperties::DEFAULT_SERVER_CLASSIFICATION_TAG)
    end
  end

  # -------------------------------------------------------------------------

  def test_policy_checks_hostname_ok
    # Hostname in json file is ignored, because it may be overridden in importer
    policy = HostnameCheckingPolicy.new({"hostnames"=>["bad.tld"]}, ["abc.tld"])
    assert_equal true, policy.import_allowed?
    assert_equal [], policy.violations
  end

  def test_policy_checks_hostname_bad_hostname
    # Hostname in json file is ignored, because it may be overridden in importer
    policy = HostnameCheckingPolicy.new({"hostnames"=>["ok.tld"]}, ["bad.tld"])
    assert_equal false, policy.import_allowed?
    assert_equal ['bad hostname'], policy.violations
  end

  class HostnameCheckingPolicy < KAppImporter::ImportPolicy
    def policy
      violation("bad hostname") if hostnames.include?("bad.tld")
    end
  end

end
