
This is Hexasphere-sw, a Swift 5 implementation of an algorithm for generating and displaying a sphere as if it were completely tiled with hexagons (except for an unavoidable seed of just 12 pentagons). This work is based in very large part on two earlier implementations, one in javascript, and another in Objective C. Please go look at those and appreciate their awesomeness as much as I have:

Javascript: https://github.com/arscan/hexasphere.js.git

Objective C: https://github.com/pkclsoft/HexasphereDemo

If you're just seriously into hexagons (hey fam), you will love those two repos, and also let me point you to https://www.redblobgames.com/grids/hexagons/ as well.

This project is structured as a Swift Package Manager package, and the simplest app I could write to demonstrate how you might use it in a Mac/iOS SceneKit app. 

I haven't tried this on iOS yet, but I don't anticipate any interesting problems, and indeed my goal is a little iOS game, more details on that later.

If you end up using this in a project of your own, I'd love to hear about it, and also you should really give proper credit to those authors I mentioned above; this Swift version represents a lot of original work, but it owes a ton to, and I learned a whole bunch from, those two working examples of how the math works.
