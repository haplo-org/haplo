/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

class HTML {
    // Tests to see if a tag name is a void tag
    // List from http://www.w3.org/TR/html-markup/syntax.html#syntax-elements
    public static boolean isVoidTag(String name) {
        switch(name) {
            case "area":
            case "base":
            case "br":
            case "col":
            case "command":
            case "embed":
            case "hr":
            case "img":
            case "input":
            case "keygen":
            case "link":
            case "meta":
            case "param":
            case "source":
            case "track":
            case "wbr":
                return true;
            default:
                return false;
        }
    }

    // Some tags may not include any child nodes because their text child
    // isn't used as part of the document.
    public static boolean cannotContainChildNodes(String name) {
        switch(name) {
            case "title":
            case "textarea":
                return true;
            default:
                return false;
        }
    }

    // Rests to see if an attribute contains a URL value.
    // List from http://www.w3.org/html/wg/drafts/html/master/index.html#attributes-1
    public static boolean attributeIsURL(String tag, String attribute) {
        switch(tag) {
            case "form":
                return attribute.equals("action");
            case "blockquote": case "del": case "ins": case "q":
                return attribute.equals("cite");
            case "object":
                return attribute.equals("data");
            case "input":
                return attribute.equals("src") || attribute.equals("formaction");
            case "button":
                return attribute.equals("formaction");
            case "a": case "area": case "link": case "base":
                return attribute.equals("href");
            case "menuitem":
                return attribute.equals("icon");
            case "html":
                return attribute.equals("manifest");
            case "video":
                return attribute.equals("src") || attribute.equals("poster");
            case "img": case "audio": case "embed":
            case "iframe": case "source": case "track":
                return attribute.equals("src");
            case "script":
                throw new RuntimeException("logic error, script tags not allowed");
            default:
                return false;
        }
    }
}
