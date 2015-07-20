var self = require('sdk/self');

var { ActionButton } = require("sdk/ui/button/action");
// var buttons = require('sdk/ui/button/action');


// a dummy function, to show how tests work.
// to see how to test this function, look at test/test-index.js
function dummy(text, callback) {
  callback(text);
}


var button = ActionButton({
    id: "my-button",
    label: "my button",
    icon: {
      "16": "./kiwiFavico16.png",
      "32": "./kiwiFavico32.png",
      "64": "./kiwiFavico64.png"      
    },
    onClick: function(state) {
        console.log("button '" + state.label + "' was clicked");
    }
  });


exports.dummy = dummy;



