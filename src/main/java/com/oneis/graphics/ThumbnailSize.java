/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.graphics;

import java.io.Serializable;

public class ThumbnailSize {
    /**
     * Dimensions of a thumbnail
     */
    static public final class Dimensions implements Serializable {
        public int width;
        public int height;

        public Dimensions() {
        }

        public Dimensions(int width, int height) {
            this.width = width;
            this.height = height;
        }

        public boolean equals(Dimensions other) {
            return (other.width == this.width) && (other.height == this.height);
        }
    }

    /**
     * Calculate the size of a thumbnail image
     */
    static public Dimensions calculate(Dimensions input, int maxDimension) {
        if(maxDimension <= 8) {
            throw new RuntimeException("maxDimension is too small");
        }

        if(input.width > maxDimension || input.height > maxDimension) {
            // Need to scale it -- work out target size
            double scale = 0.0;
            double ow = input.width;
            double oh = input.height;
            if(ow > oh) {
                scale = ((double)maxDimension) / ow;
            } else {
                scale = ((double)maxDimension) / oh;
            }
            // Limit to 1
            if(scale > 1.0) {
                scale = 1.0;
            }

            // Work out final dimensions
            int w = (int)(ow * scale);
            int h = (int)(oh * scale);
            if(w <= 0) {
                w = 1;
            }
            if(h <= 0) {
                h = 1;
            }

            return new Dimensions(w, h);
        } else {
            return new Dimensions(input.width, input.height);
        }
    }

    /**
     * Calculate the size of a thumbnail image
     */
    static public Dimensions calculate(int width, int height, int maxDimension) {
        return calculate(new Dimensions(width, height), maxDimension);
    }
}
