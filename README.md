Purpose
--------------

HTMLabel is a simple UILabel subclass for displaying basic HTML content (e.g. bold/italic, links, bullet lists) on iOS without the overhead of using a UIWebView.

HTMLLabel is **BETA** software, and as such it should be expected to have bugs. You should also expect undocumented and/or backward-incompatible changes to the interface between now and the 1.0 release. That said, it's been used in a few shipping apps now and should be safe for production use.


Installation
--------------

To use HTMLLabel in an app, just drag the class files into your project.


Usage
---------------

Because HTMLLabel is a subclass of UILabel, you can use it in exactly the same way, either in code or Interface Builder. The only difference is that the label text will be treated as HTML.

You can provide styles in the form of a dictionary of attributes keyed by tag and/or CSS-style class name. Check out the example app for details.
