# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SearchResultExcerptHighlighterTest < Test::Unit::TestCase

  TEXT = <<__E
Nam vulputate sapien a suscipit sollicitudin. Duis maximus, justo feugiat vehicula convallis, ex lorem efficitur neque, vitae tincidunt elit lorem eget risus. Nulla neque lorem, mollis id est quis, eleifend mattis dui. Suspendisse nec neque condimentum, vestibulum magna ut, interdum est. Fusce dapibus sapien scelerisque, laoreet est non, consequat est. Sed pretium eleifend urna, sit amet semper sem pretium et. Nam ultrices interdum nibh ac aliquet.
Curabitur bibendum ligula nec neque interdum, in efficitur magna molestie. Proin arcu risus, <semper> pong ac augue in, tristique ultricies enim. Vestibulum ligula nibh, dictum ac finibus euismod, viverra nec libero. Cras imperdiet sagittis tortor, consectetur sodales ipsum sollicitudin vitae. Vestibulum ut sollicitudin eros, vel gravida mauris. Morbi eu massa eget mi tempor semper eget ut nisi. Suspendisse non massa nec est accumsan ultricies. Proin et mauris ex. Fusce tempus risus sit amet erat mollis, facilisis placerat arcu sodales. Suspendisse vitae tellus ultricies, ultrices arcu a, elementum quam. Maecenas hendrerit tincidunt tellus, nec varius mauris tempor ac.
Ut eget magna a lacus condimentum placerat nec quis nisi. Phasellus sit amet lorem lobortis, ullamcorper eros vitae, tempor enim. Pellentesque lacus ex, tristique in molestie in, ultrices sit amet magna. Aenean maximus tortor in elit auctor, vel fermentum lorem aliquet. Duis commodo iaculis est, sed efficitur odio aliquet sit amet. Nunc ac gravida nisi. Mauris aliquam a dui nec pretium. Nam ac rutrum lorem. Quisque posuere et sapien ut venenatis. Aliquam posuere pulvinar mi, nec aliquet nisi rhoncus quis. Ut eu gravida massa. Nulla dignissim, tortor a tempus tincidunt, dui ipsum egestas neque, auctor pretium sapien nulla et massa.
Fusce ac dui nisl. Donec dui metus, malesuada ac tempor eget, consectetur nec nisi. Praesent lacinia world turpis sed risus faucibus, nec viverra turpis sagittis. Nunc accumsan nisi iaculis purus finibus egestas. Nam placerat ultrices diam, eget ornare metus venenatis sit amet. Aliquam facilisis quam dolor, ut semper ex accumsan in. Nulla ex libero, aliquam interdum dictum ut, facilisis nec ipsum. Quisque fringilla, mauris vel vestibulum feugiat, lorem nisi laoreet neque, sed tincidunt mi elit et dui.
__E

  EXPECTED = [
    # has HTML escaped --------------------------------------------------\/
    " nec neque interdum, in efficitur magna molestie. Proin arcu risus, &lt;semper&gt; <b>pong</b> ac augue in, tristique ultricies enim. Vestibulum ligula nibh, dictum ac",
    " nulla et massa.\nFusce ac dui nisl. Donec dui metus, malesuada ac tempor eget, consectetur nec nisi. Praesent lacinia <b>world</b> turpis sed risus faucibus, nec"
  ]

  def test_highlighter
    results = SearchResultExcerptHighlighter.highlight(TEXT, 'pong world', 160)
    assert_equal EXPECTED, results
  end

end
