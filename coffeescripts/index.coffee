self = require('sdk/self')
tabs = require("sdk/tabs")

firefoxStorage = require("sdk/simple-storage")

{ Panel } = require("sdk/panel") # { Panel } sets Panel equal to the .Panel attribute 

{ ToggleButton } = require("sdk/ui/button/toggle")

{ ActionButton } = require("sdk/ui/button/action")

# // a dummy function, to show how tests work.
# // to see how to test this function, look at test/test-index.js
# // function dummy(text, callback) {
# //   callback(text);
# // }

button = ActionButton {
    id: "my-button",
    label: "my button",
    
    badge: 0,
    
    badgeColor: "#00AAAA",
    icon: {
      "16": "./kiwiFavico16.png",
      "32": "./kiwiFavico32.png",
      "64": "./kiwiFavico64.png"
    },
    onClick: (state) ->
      console.log("button '" + state.label + "' was clicked");
      changed state
  }

tabs.on 'ready', (tab) ->
  console.log('tab is loaded', tab.title, tab.url)

firefoxStorage.storage.myArray = [1, 1, 2, 3, 5, 8, 13]
firefoxStorage.storage.myBoolean = true
firefoxStorage.storage.myNull = null
firefoxStorage.storage.myNumber = 3.1337
firefoxStorage.storage.myObject = { a: "foo", b: { c: true }, d: null }
firefoxStorage.storage.myString = "O day!"


changed = (state) ->
  button.badge = state.badge + 1
  if (state.checked) 
    button.badgeColor = "#AA00AA"
  else
    button.badgeColor = "#00AAAA"
  
  if button.badge %2 is 0
    panel.show()
  else
    panel.hide()



myScript = "window.addEventListener('click', function(event) {
              var t = event.target;
              if (t.nodeName == 'A')
                self.port.emit('click-link', t.toString());
             }, false);"

# panel = require("sdk/panel").Panel({
#   contentURL: "http://www.bbc.co.uk/mobile/index.html",
#   contentScript: myScript
# })


# panel.show();


panel = Panel({
  width: 180,
  height: 180,
  contentURL: "https://en.wikipedia.org/w/index.php?title=Jetpack&useformat=mobile",
  contentScript: myScript
});


panel.port.on("click-link", (url) ->
  console.log(url)
)





# // exports.dummy = dummy;
