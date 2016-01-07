/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.graphics;

import java.io.File;
import java.awt.*;
import java.awt.image.*;
import javax.imageio.ImageIO;

public class Thumbnail {
    public static ThumbnailSize.Dimensions scaleAndOutputRenderedImage(BufferedImage sourceImage, String outFilename, String outFormat, int maxDimension) {
        boolean ok = false;
        ThumbnailSize.Dimensions info = null;

        try {
            // Calculate size of scaled thumbnail
            ThumbnailSize.Dimensions givenSize = new ThumbnailSize.Dimensions();
            givenSize.width = sourceImage.getWidth();
            givenSize.height = sourceImage.getHeight();
            info = ThumbnailSize.calculate(givenSize, maxDimension);

            // Render it into a new image to get something the right size
            int outputType = sourceImage.getType();
            if(outputType != BufferedImage.TYPE_INT_RGB) {
                // Make sure the output type is RGB (especially if it's TYPE_CUSTOM)
                outputType = outFormat.equals("png") ? BufferedImage.TYPE_INT_ARGB : BufferedImage.TYPE_INT_RGB;
            }
            BufferedImage img = new BufferedImage(info.width, info.height, outputType);
            Image scaledImage = sourceImage.getScaledInstance(info.width, info.height, Image.SCALE_SMOOTH);
            Graphics2D graphics = img.createGraphics();
            graphics.setColor(java.awt.Color.WHITE);
            graphics.fillRect(0, 0, info.width, info.height);
            graphics.drawImage(scaledImage, 0, 0, null);
            graphics.dispose();

            ImageIO.write(img, outFormat, new File(outFilename));
            ok = true;
        } catch(Exception e) {
            // Ignore
        }
        return ok ? info : null;
    }
}
