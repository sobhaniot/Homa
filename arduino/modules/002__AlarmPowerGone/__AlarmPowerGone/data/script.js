var infoSection = document.getElementById('infoSection');
infoSection.addEventListener("click",function () {
    document.getElementById('information').classList.toggle("toggle");
})
var timeSection = document.getElementById('timeSection');
timeSection.addEventListener("click",function () {
    document.getElementById('timeSlide').classList.toggle("toggle");
})
var ssid = document.getElementById('ssid');
ssid.addEventListener("click",function () {
    document.getElementById('ssidslide').classList.toggle("toggle");
})
var allText;

function readTextFile() {
  var rawFile = new XMLHttpRequest();
  rawFile.open("GET", "info.txt", true);
  rawFile.onreadystatechange = function() {
    if (rawFile.readyState === 4) {
      var allText = rawFile.responseText;
      var allData = allText.split('\n');
      allData.forEach(appendFunc);
    }
  }
  rawFile.send();
}
function appendFunc(item, index){
    document.getElementById('information').innerHTML += '<p>' + item + '</p>';
}

readTextFile();

