/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

(function($) {

    $(document).ready(function() {

        // Expand statistic groups when visualisation clicked
        $(document).on("click", ".z__std_reporting_summary_display_statistic_number a", function(evt) {
            evt.preventDefault();
            var w = this.offsetWidth, h = this.offsetHeight;

            // Find statistics grouped breakdown
            var statistic = $(this).parents(".z__std_reporting_summary_display_statistic").first();
            var groups = $.parseJSON(statistic[0].getAttribute('data-groups'));

            // Generate grouped info table
            var table = ['<table style="width:60%">'];
            var colours = $.data(this, "reporting-colours");
            table.push('<caption><b>'+_.escape(statistic[0].getAttribute('data-groups-title'))+'</b></caption>');
            _.each(_.sortBy(groups, "1"), function(g, index) {
                table.push('<tr><td><span class="z__std_reporting_summary_display_groupedresults_blob" style="width:', w, 'px; height:', h, 'px; background:', colours[index], '"></span>',
                    _.escape(g[1]),'</td><td>',_.escape(""+g[0]),
                    '</td></tr>'
                );
            });
            table.push("</table>");

            // Insert into document
            var container = $(this).parents(".z__std_reporting_summary_display_container").first();
            $(".z__std_reporting_summary_display_groupedresults", container).html(table.join(""));
        });

        // ------------------------------------------------------------------

        // Generate colours
        var colourIndex = 0;
        var nextColour = function() {
            colourIndex++;
            if(colourIndex >= 7) { colourIndex = 1; }
            return '#' + ((colourIndex & 1) ? 'f' : '0') + ((colourIndex & 2) ? 'f' : '0') + ((colourIndex & 4) ? 'f' : '0');
        };

        // Generate a temporary visualisation
        // TODO: Better sumnmary statistic visualisation
        $('.z__std_reporting_summary_display_statistic[data-groups]').each(function() {
            var groups = $.parseJSON(this.getAttribute('data-groups'));
            var link = $('.z__std_reporting_summary_display_statistic_number a', this)[0];
            var linkWidth = link.offsetWidth;

            var sum = 0;
            var spans = [];
            _.each(groups, function(g) { sum += g[0]; });
            var colours = [];
            if(sum === 0) { sum = 0.00001; }
            _.each(_.sortBy(groups, "1"), function(g) {
                var width = (linkWidth * g[0]) / sum;
                var colour = nextColour();
                colours.push(colour);
                spans.push('<span style="background:', colour, '; width:', width, 'px" title="', _.escape(g[1]), '"></span>');
            });
            $.data(link, "reporting-colours", colours);

            link.innerHTML = spans.join('');
        });

    });

})(jQuery);
