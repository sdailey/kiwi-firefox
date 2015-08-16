
self = require('sdk/self')
tabs = require("sdk/tabs")

base64 = require("sdk/base64")

firefoxStorage = require("sdk/simple-storage")
Panel = require("sdk/panel").Panel  # <-> same thing, but one is clearer   # { Panel } = require("sdk/panel")
IconButton = require("sdk/ui/button/action").ActionButton

{ setTimeout, clearTimeout } = require("sdk/timers")

{ Cc, Ci } = require('chrome')

# kiwi_popup = require('./KiwiPopup')

Request = require("sdk/request").Request

_ = require('./data/vendor/underscore-min')


tabUrl = ''

tabTitleObject = null

popupOpen = false

checkForUrlHourInterval = 16

checkForUrl_Persistent_ChromeNotification_HourInterval = 3 # (max of 5 notification items)

last_periodicCleanup = 0 # timestamp

CLEANUP_INTERVAL = 3 * 3600000 # three hours

queryThrottleSeconds = 3 # to respect the no-more-than 30/min stiplation for Reddit's api

serviceQueryTimestamps = {}

maxUrlResultsStoredInLocalStorage = 800 # they're deleted after they've expired anyway - so this likely won't be reached by user

popupParcel = {}
  # proactively set if each services' preppedResults are ready.
  # will be set with available results if queried by popup.
  # {
    # forUrl:
    # allPreppedResults:
    # kiwi_servicesInfo:
    # kiwi_customSearchResults:
    # kiwi_alerts:
    # kiwi_userPreferences:
  # }

kiwi_urlsResultsCache = {}  
  # < url >:
    # < serviceName >: {
    #   forUrl: url
    #   timestamp:
    #   service_PreppedResults: 
    #   urlBlocked:
    # }

kiwi_customSearchResults = {}  # stores temporarily so if they close popup, they'll still have results
      # maybe it won't clear until new result -- "see last search"
  
  # queryString
  # servicesSearchesRequested = responsePackage.servicesToSearch
  # servicesSearched
    # <serviceName>
      # results

kiwi_autoOffClearInterval = null

kiwi_reddit_token_refresh_interval = null
  # timestamp: 
  # intervalId: 
  
kiwi_productHunt_token_refresh_interval = null
  # timestamp: 
  # intervalId:   
  

tempResponsesStore = {}
  # forUrl: < url >
  # results: 
    # < serviceName > :
    #   timestamp:
    #   service_PreppedResults:
    #   forUrl: url


defaultUserPreferences = {
  
  fontSize: .8 # not yet implemented
  researchModeOnOff: 'off' # or 'on'
  autoOffAtUTCmilliTimestamp: null
  autoOffTimerType: 'always' # 'custom','always','20','60'
  autoOffTimerValue: null
  
  sortByPref: 'attention' # 'recency'   # "attention" means 'comments' if story, 'points' if comment, 'clusterUrl' if news
  
  installedTime: Date.now()
  
  urlSubstring_whitelists:
    anyMatch: []
    beginsWith: []
    endingIn: []
    unless: [
      # ['twitter.com/','/status/'] # unless /status/
    ]
  
  
  
    # suggested values to all users  -- any can be overriden with the "Research this URL" button
      # unfortunately, because of Chrome's discouragement of storing sensitive 
      # user info with chrome.storage, blacklists are fixed for now . see: https://news.ycombinator.com/item?id=9993030
  urlSubstring_blacklists: 
    anyMatch: [
      'facebook.com'
      
      'news.ycombinator.com'
      'reddit.com'
      
      'imgur.com'
      
      'www.google.com'
      'docs.google'
      'drive.google'
      'accounts.google'
      '.slack.com/'
      '//t.co'
      '//bit.ly'
      '//goo.gl'
      '//mail.google'
      '//mail.yahoo.com'
      'hotmail.com'
      'outlook.com'
      
      
      'chrome-extension://'
      
      'chrome-devtools://'  # hardcoded block
      
      # "about:blank"
      # "about:newtab"
    ]
    beginsWith: [
      "about:"
      'chrome://'
    ]
    endingIn: [
      #future - ending in:
      'youtube.com' # /
    ]
    unless: [
      #unless 
      ['twitter.com/','/status/'] # unless /status/
    # ,
    #   'twitter.com'
    ]
}

defaultServicesInfo = [
    
    name:"hackerNews"
    title: "Hacker News"
    abbreviation: "H"
    
    queryApi:"https://hn.algolia.com/api/v1/search?restrictSearchableAttributes=url&query="
    
    broughtToYouByTitle:"Algolia Hacker News API"
    broughtToYouByURL:"https://hn.algolia.com/api"
    
    brandingImage: null
    brandingSlogan: null
    
    permalinkBase: 'https://news.ycombinator.com/item?id='
    userPageBaselink: 'https://news.ycombinator.com/user?id='
    
    submitTitle: 'Be the first to submit on Hacker News!'
    submitUrl: 'https://news.ycombinator.com/submit'
    
    active: 'on'
    
    notableConditions:
      hoursSincePosted: 4 # an exact match is less than 5 hours old
      num_comments: 10  # an exact match has 10 comments
    
    updateBadgeOnlyWithExactMatch: true
    
    customSearchApi: "https://hn.algolia.com/api/v1/search?query="
    customSearchTags__convention: {'string':'&tags=','delimeter':','}
    customSearchTags:
      story:
        title: "stories"
        string: "story"
        include: true
      commentPolls:
        title: "comments or polls"
        string:"(comment,poll,pollopt)"
        include: false
      showHnAskHn:
        title: "Show HN or Ask HN"
        string:"(show_hn,ask_hn)"
        include: false
        
    # customSearch
    # queryApi  https://hn.algolia.com/api/v1/search?query=
      # tags= filter on a specific tag. Available tags:
      # story
      # comment
      # poll
      # pollopt
      # show_hn
      # ask_hn
      # front_page
      # author_:USERNAME
      # story_:ID
      
      # author_pg,(story,poll)   filters on author=pg AND (type=story OR type=poll).
    customSearchBroughtToYouByURL: null
    customSearchBroughtToYouByTitle: null
    
    conversationSite: true
  ,
  
    name:"reddit"
    title: "reddit"
    abbreviation: "R"
    
    queryApi:"https://www.reddit.com/submit.json?url="
    
    broughtToYouByTitle:"Reddit API"
    
    broughtToYouByURL:"https://github.com/reddit/reddit/wiki/API"
    
    brandingImage: null
    brandingSlogan: null
    
    permalinkBase: 'https://www.reddit.com'
    
    userPageBaselink: 'https://www.reddit.com/user/'
    
    submitTitle: 'Be the first to submit on Reddit!'
    submitUrl: 'https://www.reddit.com/submit'
    
    
    active: 'on'
    
    notableConditions:
      hoursSincePosted: 1 # an exact match is less than 5 hours old
      num_comments: 30   # an exact match has 30 comments
    
    updateBadgeOnlyWithExactMatch: true
    
    customSearchApi: "https://www.reddit.com/search.json?q="
    
    customSearchTags: {}
    
    customSearchBroughtToYouByURL: null
    customSearchBroughtToYouByTitle: null
    
    conversationSite: true
  ,
  
    name:"productHunt"
    title: "Product Hunt"
    abbreviation: "P"
    
    queryApi:"https://api.producthunt.com/v1/posts/all?search[url]="
    
    broughtToYouByTitle:"Product Hunt API"
    
    broughtToYouByURL:"https://api.producthunt.com/v1/docs"
    
    permalinkBase: 'https://producthunt.com/'
    
    userPageBaselink: 'https://www.producthunt.com/@'
    
    brandingImage: "product-hunt-logo-orange-240.png"
    brandingSlogan: null
    
    submitTitle: 'Be the first to submit to Product Hunt!'
    submitUrl: 'https://www.producthunt.com/tech/new'
    
    active: 'on'
    
    notableConditions:
      hoursSincePosted: 4 # an exact match is less than 5 hours old
      num_comments: 10   # an exact match has 30 comments
      
      # 'featured'
      
      
    updateBadgeOnlyWithExactMatch: true
    
      # uses Algolia index, not a typical rest api
    customSearchApi: ""
    customSearchTags: {}
    customSearchBroughtToYouByURL: 'https://www.algolia.com/doc/javascript'
    customSearchBroughtToYouByTitle: "Algolia's Search API"
    
    conversationSite: true
    
  # {
  #  so many great communities out there! ping me @spencenow if an API surfaces for yours!
  # 2015-8-13 - producthunt has been implemented! holy crap this is cool! :D 
    # working on Slashdot...!
  # },
  
]

shuffle_array = (array) ->
  currentIndex = array.length;

  # // While there remain elements to shuffle...
  while (0 != currentIndex) 

    # // Pick a remaining element...
    randomIndex = Math.floor(Math.random() * currentIndex);
    currentIndex -= 1;

    # // And swap it with the current element.
    temporaryValue = array[currentIndex];
    array[currentIndex] = array[randomIndex];
    array[randomIndex] = temporaryValue;
  

  return array

randomizeDefaultConversationSiteOrder = ->
  conversationSiteServices = []
  nonConversationSiteServices = []
  
  
  for service in defaultServicesInfo
    if service.conversationSite
      conversationSiteServices.push service
    else
      nonConversationSiteServices.push service
  
  newDefaultServices = []
  
  conversationSiteServices = shuffle_array(conversationSiteServices)
  defaultServicesInfo = conversationSiteServices.concat(nonConversationSiteServices)

randomizeDefaultConversationSiteOrder()

# ~~~ starting out with negotiating oAuth tokens and initializing necessary api objects ~~~ # 

getRandom = (min, max) ->
  return min + Math.floor(Math.random() * (max - min + 1))

reduceHashByHalf = (hash, reducedByAFactorOf = 1) ->
  
  reduceStringByHalf = (_string_) ->
    newShortenedString = ''
    for char, index in _string_
      
      if index % 2 is 0 and (_string_.length - 1 > index + 1)
        char = if char > _string_[index + 1] then char else _string_[index + 1]
        newShortenedString += char
    return newShortenedString
    
  finalHash = ''
  
  counter = 0
  
  while counter < reducedByAFactorOf
    hash = reduceStringByHalf(hash)
    counter++
  
  return hash
  
kiwi_iconButton = IconButton {
    id: "kiwi-button",
    label: "Kiwi Conversations",
    
    badge: '',
    
    badgeColor: "#00AAAA",
    icon: {
      "16": "./kiwiFavico16.png",
      "32": "./kiwiFavico32.png",
      "64": "./kiwiFavico64.png"
    },
    onClick: (iconButtonState) ->
      # console.log("button '" + iconButtonState.label + "' was clicked")
      iconButtonClicked(iconButtonState)
  }

iconButtonClicked = (iconButtonState) ->
  # kiwi_iconButton.badge = iconButtonState.badge + 1
  
  if (iconButtonState.checked) 
    kiwi_iconButton.badgeColor = "#AA00AA"
  else
    kiwi_iconButton.badgeColor = "#00AAAA"
  
  kiwiPP_request_popupParcel()
  kiwi_panel.show({'position':kiwi_iconButton})

    
    # <link rel="stylesheet" href="vendor/bootstrap-3.3.5-dist/css/bootstrap.min.css"></link>
    # <link rel="stylesheet" href="vendor/bootstrap-3.3.5-dist/css/bootstrap-theme.min.css"></link>
    # <link rel="stylesheet" href="vendor/behigh-bootstrap_dropdown_enhancement/css/dropdowns-enhancement.min.css"></link>
    
    
    # <script src="vendor/jquery-2.1.4.min.js" ></script>
    # <script src="vendor/Underscore1-8-3.js"></script>
    # <script src="vendor/bootstrap-3.3.5-dist/js/bootstrap.min.js"></script>
    # <script src=""></script>

kiwiPP_request_popupParcel = (dataFromPopup = {}) ->
  
  # console.log 'kiwiPP_request_popupParcel = (dataFromPopup = {}) ->'
  
  popupOpen = true

  preppedResponsesInPopupParcel = 0
  if popupParcel? and popupParcel.allPreppedResults? 
    #console.log 'popupParcel.allPreppedResults? '
    #console.debug popupParcel.allPreppedResults
    
    for serviceName, service of popupParcel.allPreppedResults
      if service.service_PreppedResults?
        preppedResponsesInPopupParcel += service.service_PreppedResults.length
  
  preppedResponsesInTempResponsesStore = 0
  if tempResponsesStore? and tempResponsesStore.services? 
    
    for serviceName, service of tempResponsesStore.services
      preppedResponsesInTempResponsesStore += service.service_PreppedResults.length
  
  newResultsBool = false
  
  if tempResponsesStore.forUrl == tabUrl and preppedResponsesInTempResponsesStore != preppedResponsesInPopupParcel
    newResultsBool = true
  
  if popupParcel? and popupParcel.forUrl is tabUrl and newResultsBool == false
    #console.log "popup parcel ready"
    
    parcel = {}
    
    parcel.msg = 'kiwiPP_popupParcel_ready'
    parcel.forUrl = tabUrl
    parcel.popupParcel = popupParcel
    
    sendParcel(parcel)
  else
    
    if !tempResponsesStore.services? or tempResponsesStore.forUrl != tabUrl
      _set_popupParcel({}, tabUrl, true)
    else
      _set_popupParcel(tempResponsesStore.services, tabUrl, true)

kiwi_panel = Panel({
  width: 500,
  height: 640, 
  # contentURL: "https://en.wikipedia.org/w/index.php?title=Jetpack&useformat=mobile",
  contentURL: "./popup.html",
  contentStyleFile: ["./bootstrap-3.3.5-dist/css/bootstrap.min.css", 
    "./bootstrap-3.3.5-dist/css/bootstrap-theme.min.css", 
    "./behigh-bootstrap_dropdown_enhancement/css/dropdowns-enhancement.min.css"
  ],
  contentScriptFile: ["./vendor/jquery-2.1.4.min.js", 
    "./vendor/underscore-min.js", 
    "./behigh-bootstrap_dropdown_enhancement/js/dropdowns-enhancement.js",
    "./vendor/algoliasearch.min.js",
  "./KiwiPopup.js"]
})


updateBadgeText = (newBadgeText) ->
  kiwi_iconButton.badge = newBadgeText

randomishDeviceId = ->   # to be held in localStorage
  randomClientLength = getRandom(21,29)
  
  characterCounter = 0 
  
  randomString = ""
  
  while characterCounter <= randomClientLength
    characterCounter++
    
    randomASCIIcharcode = getRandom(33,125)
    #console.log randomASCIIcharcode
    randomString += String.fromCharCode(randomASCIIcharcode)
  
  return randomString
  

setTimeout_forRedditRefresh = (token_timestamp, kiwi_reddit_oauth) ->
  currentTime = Date.now()
  
  if kiwi_reddit_token_refresh_interval? and kiwi_reddit_token_refresh_interval.timestamp?
    clearTimeout(kiwi_reddit_token_refresh_interval.intervalId)
  
  timeoutDelay = token_timestamp - currentTime
  
  timeoutIntervalId = setTimeout( -> 
      requestRedditOathToken(kiwi_reddit_oauth)
    , timeoutDelay )
  
  
  kiwi_reddit_token_refresh_interval =
    timestamp: token_timestamp
    intervalId: timeoutIntervalId

requestRedditOathToken = (kiwi_reddit_oauth) ->
  
  currentTime = Date.now()
  Request({
    url: 'https://www.reddit.com/api/v1/access_token',
    headers: { 
      'Authorization':    'Basic ' + base64.encode(kiwi_reddit_oauth.client_id + ":")
      'Content-Type':     'application/x-www-form-urlencoded'
      'X-Requested-With': 'csrf suck it ' + getRandom(1,10000000) # not that the random # matters
    },
    content: {
        grant_type: "https://oauth.reddit.com/grants/installed_client"
        device_id: kiwi_reddit_oauth.device_id
    },
    onComplete: (response) ->
      if(response.status == 0 or response.status == 504)
            # // do connection timeout handling
        # console.log 'reddit response timeout'
        # console.log response
        # console.log response.status
        setTimeout( ->
          requestRedditOathToken(kiwi_reddit_oauth)
          # requestProductHuntOauthToken(kiwi_productHunt_oauth)
        , 1000 * 60 * 3
        )
      else
        if response.json.access_token? and response.json.expires_in? and response.json.token_type == "bearer"
          #console.log 'response from reddit!'
          
          token_lifespan_timestamp = currentTime + response.json.expires_in * 1000
          
          setObj =
            token: response.json.access_token
            token_type: 'bearer'
            token_lifespan_timestamp: token_lifespan_timestamp
            client_id: kiwi_reddit_oauth.client_id
            device_id: kiwi_reddit_oauth.device_id
          
          firefoxStorage.storage.kiwi_reddit_oauth = setObj
          
          setTimeout_forRedditRefresh(token_lifespan_timestamp, setObj)
        
  }).post()
  

setTimeout_forProductHuntRefresh = (token_timestamp, kiwi_productHunt_oauth) ->
  currentTime = Date.now()
  if kiwi_productHunt_token_refresh_interval? and kiwi_productHunt_token_refresh_interval.timestamp?
    clearTimeout(kiwi_productHunt_token_refresh_interval.intervalId)
  
  timeoutDelay = token_timestamp - currentTime
  
  timeoutIntervalId = setTimeout( -> 
      requestProductHuntOauthToken(kiwi_productHunt_oauth)
    , timeoutDelay )
  
  kiwi_productHunt_token_refresh_interval =
    timestamp: token_timestamp
    intervalId: timeoutIntervalId

requestProductHuntOauthToken = (kiwi_productHunt_oauth) ->
  currentTime = Date.now()
  Request({
    content: {
      "client_id": kiwi_productHunt_oauth.client_id
      "client_secret": kiwi_productHunt_oauth.client_secret
      "grant_type" : "client_credentials"
    }
    
    url: 'https://api.producthunt.com/v1/oauth/token'
    headers: {}
    onComplete: (response) ->
      
      if(response.status == 0 or response.status == 504)
            # // do connection timeout handling
        # console.log 'ph response timeout'
        # console.log response
        # console.log response.status
        setTimeout( ->
          requestProductHuntOauthToken(kiwi_productHunt_oauth)
          # requestProductHuntOauthToken(kiwi_productHunt_oauth)
        , 1000 * 60 * 3
        )
      else
        # console.log 'check this'
        # console.log response.json
        if response.json? and response.json.access_token? and response.json.expires_in? and response.json.token_type == "bearer"
          token_lifespan_timestamp = currentTime + response.json.expires_in * 1000
          setObj = {}
          setObj =
            token: response.json.access_token
            scope: "public"
            token_type: 'bearer'
            token_lifespan_timestamp: token_lifespan_timestamp
            client_id: kiwi_productHunt_oauth.client_id
            client_secret: kiwi_productHunt_oauth.client_secret
          
          firefoxStorage.storage.kiwi_productHunt_oauth = setObj
          setTimeout_forProductHuntRefresh(token_lifespan_timestamp, setObj)
          
  }).post()
  

negotiateOauthTokens = ->
  currentTime = Date.now()
  
  temp__kiwi_productHunt_oauth =
    token: null
    token_type: null
    token_lifespan_timestamp: null
    client_id: "" # your client id here
    client_secret: "" # your secret id here
    
  if !firefoxStorage.storage.kiwi_productHunt_oauth? or !firefoxStorage.storage.kiwi_productHunt_oauth.token?
    # console.log 'ph oauth does not exist in firefox storage'
    
    requestProductHuntOauthToken(temp__kiwi_productHunt_oauth)
  
  if !firefoxStorage.storage.kiwi_productHunt_oauth? or !firefoxStorage.storage.kiwi_productHunt_oauth.token?
    # do nothing
    
  else if (firefoxStorage.storage.kiwi_productHunt_oauth.token_lifespan_timestamp? and 
      currentTime > firefoxStorage.storage.kiwi_productHunt_oauth.token_lifespan_timestamp) or
      !firefoxStorage.storage.kiwi_productHunt_oauth.token_lifespan_timestamp?
    
    #console.log "3 setObj['kiwi_productHunt_oauth'] ="
    
    requestProductHuntOauthToken(temp__kiwi_productHunt_oauth)
    
  else if firefoxStorage.storage.kiwi_productHunt_oauth.token_lifespan_timestamp? and firefoxStorage.storage.kiwi_productHunt_oauth?
    
    #console.log "4 setObj['kiwi_productHunt_oauth'] ="
    
    token_timestamp = firefoxStorage.storage.kiwi_productHunt_oauth.token_lifespan_timestamp
    
    if !kiwi_productHunt_token_refresh_interval? or kiwi_productHunt_token_refresh_interval.timestamp != token_timestamp
      
      setTimeout_forProductHuntRefresh(token_timestamp, firefoxStorage.storage.kiwi_productHunt_oauth)
  
  temp__kiwi_reddit_oauth =
    token: null
    token_type: null
    token_lifespan_timestamp: null
    client_id: "" # your client id here
    device_id: randomishDeviceId()
    
  if !firefoxStorage.storage.kiwi_reddit_oauth? or !firefoxStorage.storage.kiwi_reddit_oauth.token?
    requestRedditOathToken(temp__kiwi_reddit_oauth)
  
  if !firefoxStorage.storage.kiwi_reddit_oauth? or !firefoxStorage.storage.kiwi_reddit_oauth.token?
    
    # do nothing
    
  else if (firefoxStorage.storage.kiwi_reddit_oauth.token_lifespan_timestamp? and 
      currentTime > firefoxStorage.storage.kiwi_reddit_oauth.token_lifespan_timestamp) or
      !firefoxStorage.storage.kiwi_reddit_oauth.token_lifespan_timestamp?
    
    #console.log "3 setObj['kiwi_reddit_oauth'] ="
    
    requestRedditOathToken(temp__kiwi_reddit_oauth)
    
  else if firefoxStorage.storage.kiwi_reddit_oauth.token_lifespan_timestamp? and firefoxStorage.storage.kiwi_reddit_oauth?
    
    #console.log "4 setObj['kiwi_reddit_oauth'] ="
    
    token_timestamp = firefoxStorage.storage.kiwi_reddit_oauth.token_lifespan_timestamp
    
    if !kiwi_reddit_token_refresh_interval? or kiwi_reddit_token_refresh_interval.timestamp != token_timestamp
      
      setTimeout_forRedditRefresh(token_timestamp, firefoxStorage.storage.kiwi_reddit_oauth)

negotiateOauthTokens()

is_url_blocked = (blockedLists, url) ->
  return doesURLmatchSubstringLists(blockedLists, url)

is_url_whitelisted = (whiteLists, url) ->
  return doesURLmatchSubstringLists(whiteLists, url)

doesURLmatchSubstringLists = (urlSubstringLists, url) ->
  if urlSubstringLists.anyMatch?
    for urlSubstring in urlSubstringLists.anyMatch
      if url.indexOf(urlSubstring) != -1
        return true
  
  if urlSubstringLists.beginsWith?
    for urlSubstring in urlSubstringLists.beginsWith
      if url.indexOf(urlSubstring) == 0
        return true
  
  if urlSubstringLists.endingIn?
    for urlSubstring in urlSubstringLists.endingIn
      if url.indexOf(urlSubstring) == url.length - urlSubstring.length
        return true
        
      urlSubstring += '/'
      if url.indexOf(urlSubstring) == url.length - urlSubstring.length
        return true
    
  if urlSubstringLists.unless?
    for urlSubstringArray in urlSubstringLists.unless
      if url.indexOf(urlSubstringArray[0]) != -1
        
        if url.indexOf(urlSubstringArray[1]) == -1
          return true
  
  return false

    



returnNumberOfActiveServices = (servicesInfo) ->
  
  numberOfActiveServices = 0
  for service in servicesInfo
    if service.active == 'on'
      numberOfActiveServices++
  return numberOfActiveServices



sendParcel = (parcel) ->
  
  if !parcel.msg? or !parcel.forUrl?
    return false
  
  switch parcel.msg
    when 'kiwiPP_popupParcel_ready'
      
      kiwi_panel.port.emit('kiwi_fromBackgroundToPopup', parcel)
      
    
_save_a_la_carte = (parcel) ->
  
  firefoxStorage.storage[parcel.keyName] = parcel.newValue
  
  if !tempResponsesStore? or !tempResponsesStore.services?
    tempResponsesStoreServices = {}
  else
    tempResponsesStoreServices = tempResponsesStore.services
  if parcel.refreshView?
    _set_popupParcel(tempResponsesStoreServices, tabUrl, true, parcel.refreshView)
  else
    _set_popupParcel(tempResponsesStoreServices, tabUrl, false)




kiwi_panel.port.on("kiwiPP_post_customSearch", (dataFromPopup) ->
  popupOpen = true
  
  if dataFromPopup.customSearchRequest? and dataFromPopup.customSearchRequest.queryString? and
      dataFromPopup.customSearchRequest.queryString != ''
      
    if firefoxStorage.storage['kiwi_servicesInfo']?
      # #console.log 'when kiwiPP_post_customSearch3'
      for serviceInfoObject in firefoxStorage.storage['kiwi_servicesInfo']
        
        #console.log 'when kiwiPP_post_customSearch4 for ' + serviceInfoObject.name
        if dataFromPopup.customSearchRequest.servicesToSearch[serviceInfoObject.name]?
          
          # console.log 'trying custom search PH' 
          # console.log dataFromPopup.customSearchRequest.servicesToSearch.productHunt.rawResults
          
          if serviceInfoObject.name is 'productHunt' and dataFromPopup.customSearchRequest.servicesToSearch.productHunt.rawResults?
            
            responsePackage = {
              servicesInfo: firefoxStorage.storage['kiwi_servicesInfo']
              
              servicesToSearch: dataFromPopup.customSearchRequest.servicesToSearch
              customSearchQuery: dataFromPopup.customSearchRequest.queryString
              
              serviceName: serviceInfoObject.name
              queryResult: dataFromPopup.customSearchRequest.servicesToSearch.productHunt.rawResults
            }
            
            setPreppedServiceResults__customSearch(responsePackage, firefoxStorage.storage['kiwi_servicesInfo'])
            
          else
            if serviceInfoObject.customSearchApi? and serviceInfoObject.customSearchApi != ''
              dispatchQuery__customSearch(dataFromPopup.customSearchRequest.queryString, dataFromPopup.customSearchRequest.servicesToSearch, serviceInfoObject, firefoxStorage.storage['kiwi_servicesInfo'])
  
)

kiwi_panel.port.on "kiwiPP_researchUrlOverrideButton", (dataFromPopup) ->
  popupOpen = true
  initIfNewURL(true,true)


kiwi_panel.port.on "kiwiPP_clearAllURLresults", (dataFromPopup) ->
  popupOpen = true
  updateBadgeText('')
  
  kiwi_urlsResultsCache = {}
  tempResponsesStore = {}
  _set_popupParcel({}, tabUrl, true)
  

kiwi_panel.port.on "kiwiPP_refreshSearchQuery", (dataFromPopup) ->
  popupOpen = true
  kiwi_customSearchResults = {}
  
  if tempResponsesStore.forUrl == tabUrl
    
    _set_popupParcel(tempResponsesStore.services, tabUrl, true)
  
  else if kiwi_urlsResultsCache[tabUrl]?
    
    _set_popupParcel(kiwi_urlsResultsCache[tabUrl], tabUrl, true)
    
  else
    _set_popupParcel({}, tabUrl, true)

kiwi_panel.port.on "kiwiPP_refreshURLresults", (dataFromPopup) ->
  popupOpen = true
  if kiwi_urlsResultsCache? and kiwi_urlsResultsCache[tabUrl]?
    delete kiwi_urlsResultsCache[tabUrl]
    
  tempResponsesStore = {}
  initIfNewURL(true)

kiwi_panel.port.on "kiwiPP_reset_timer", (dataFromPopup) ->
  popupOpen = true
  
  dataFromPopup.kiwi_userPreferences['autoOffAtUTCmilliTimestamp'] = setAutoOffTimer(true,
      dataFromPopup.kiwi_userPreferences.autoOffAtUTCmilliTimestamp, 
      dataFromPopup.kiwi_userPreferences.autoOffTimerValue,
      dataFromPopup.kiwi_userPreferences.autoOffTimerType,
      dataFromPopup.kiwi_userPreferences.researchModeOnOff
    )
  parcel =
    refreshView: 'userPreferences'
    keyName: 'kiwi_userPreferences'
    newValue: dataFromPopup.kiwi_userPreferences
    localOrSync: 'sync'
  
  _save_a_la_carte(parcel)

kiwi_panel.port.on "kiwiPP_post_save_a_la_carte", (dataFromPopup) ->
  popupOpen = true
  _save_a_la_carte(dataFromPopup)

kiwi_panel.port.on "kiwiPP_post_savePopupParcel", (dataFromPopup) ->
  popupOpen = true
  _save_from_popupParcel(dataFromPopup.newPopupParcel, tabUrl, dataFromPopup.refreshView)
  if kiwi_urlsResultsCache[tabUrl]?
    refreshBadge(dataFromPopup.newPopupParcel.kiwi_servicesInfo, kiwi_urlsResultsCache[tabUrl])
  

      
kiwi_panel.port.on "kiwiPP_request_popupParcel", (dataFromPopup) ->
  
  kiwiPP_request_popupParcel(dataFromPopup)
  
initialize = (currentUrl) ->
  
  if !firefoxStorage.storage.kiwi_servicesInfo?
    
    firefoxStorage.storage.kiwi_servicesInfo = defaultServicesInfo
    getUrlResults_to_refreshBadgeIcon(defaultServicesInfo, currentUrl)  
  else
    
    getUrlResults_to_refreshBadgeIcon(firefoxStorage.storage['kiwi_servicesInfo'], currentUrl)
  
  
getUrlResults_to_refreshBadgeIcon = (servicesInfo, currentUrl) ->
  
  currentTime = Date.now()
  
  if Object.keys(kiwi_urlsResultsCache).length > 0
    
     # to prevent repeated api requests - we check to see if we have up-to-date request results in local storage
    if kiwi_urlsResultsCache[currentUrl]?
      
      # start off by instantly updating UI with what we know
      refreshBadge(servicesInfo, kiwi_urlsResultsCache[currentUrl])
      
      for service in servicesInfo
        if kiwi_urlsResultsCache[currentUrl][service.name]?
          
          if (currentTime - kiwi_urlsResultsCache[currentUrl][service.name].timestamp) > checkForUrlHourInterval * 3600000
            
            check_updateServiceResults(servicesInfo, currentUrl, kiwi_urlsResultsCache)  
            return 0
          
        else
          check_updateServiceResults(servicesInfo, currentUrl, kiwi_urlsResultsCache)  
          return 0
      
      # for urls that are being visited a second time, 
      # all recent results present kiwi_urlsResultsCache (for all services)
      # we set tempResponsesStore before setting popupParcel
      
      tempResponsesStore.forUrl = currentUrl
      tempResponsesStore.services = kiwi_urlsResultsCache[currentUrl]
      
      #console.log '#console.debug tempResponsesStore.services'
      #console.debug tempResponsesStore.services
      _set_popupParcel(tempResponsesStore.services, currentUrl, true)
      
          
    else
      # this url has not been checked
      #console.log '# this url has not been checked'
      check_updateServiceResults(servicesInfo, currentUrl, kiwi_urlsResultsCache)
        
  else
    
    #console.log '# no urls have been checked'
    check_updateServiceResults(servicesInfo, currentUrl, null)


_save_url_results = (servicesInfo, tempResponsesStore, _urlsResultsCache) ->
  #console.log 'yolo 3'
  
  urlsResultsCache = _.extend {}, _urlsResultsCache
  previousUrl = tempResponsesStore.forUrl
  
  if urlsResultsCache[previousUrl]? 
    
      # these will always be at least as recent as what's in the store. 
    for service in servicesInfo
      
      if tempResponsesStore.services[service.name]?
        
        urlsResultsCache[previousUrl][service.name] =
          forUrl: previousUrl
          timestamp: tempResponsesStore.services[service.name].timestamp
          service_PreppedResults: tempResponsesStore.services[service.name].service_PreppedResults
      
  else
    
    urlsResultsCache[previousUrl] = {}
    urlsResultsCache[previousUrl] = tempResponsesStore.services
    
  return urlsResultsCache
  


__randomishStringPadding = ->
  randomPaddingLength = getRandom(1,3)
      
  characterCounter = 0
  
  paddingString = ""
  
  while characterCounter <= randomPaddingLength
    
    randomLatinKeycode = getRandom(33,121)
    String.fromCharCode(randomLatinKeycode)
    
    paddingString += String.fromCharCode(randomLatinKeycode)
    characterCounter++
  
  return paddingString


toSHA512 = (str) ->

  # // Convert string to an array of bytes
  array = Array.prototype.slice.call(str)

  # // Create SHA512 hash
  hashEngine = Cc["@mozilla.org/security/hash;1"].createInstance(Ci.nsICryptoHash)
  hashEngine.init(hashEngine.MD5)
  hashEngine.update(array, array.length)
  return hashEngine.finish(true)


_save_historyBlob = (kiwi_urlsResultsCache, tabUrl) ->
  
  
  tabUrl_hash = toSHA512(tabUrl)
  
    # firefox's toSHA512 function usually returned a string ending in "=="
  tabUrl_hash = tabUrl_hash.substring(0, tabUrl_hash.length - 2);
  historyString = reduceHashByHalf(tabUrl_hash)
  
  
  paddedHistoryString = __randomishStringPadding() + historyString + __randomishStringPadding()
  
  if firefoxStorage.storage.kiwi_historyBlob? and typeof firefoxStorage.storage.kiwi_historyBlob == 'string' and
      firefoxStorage.storage.kiwi_historyBlob.indexOf(historyString) < 15000 and firefoxStorage.storage.kiwi_historyBlob.indexOf(historyString) != -1
    
    #console.log '# already exists in history blob ' + allItemsInLocalStorage.kiwi_historyBlob.indexOf(historyString)
    
    return 0
    
  else
    
    if firefoxStorage.storage['kiwi_historyBlob']?
      newKiwi_historyBlob = paddedHistoryString + firefoxStorage.storage['kiwi_historyBlob']
    else
      newKiwi_historyBlob = paddedHistoryString
  
  
  
    # we cap the size of the history blob at 17000 characters
  if firefoxStorage.storage.kiwi_historyBlob? and  firefoxStorage.storage.kiwi_historyBlob.indexOf(historyString) > 17000
    newKiwi_historyBlob = newKiwi_historyBlob.substring(0,15500)
  
  firefoxStorage.storage.kiwi_historyBlob = newKiwi_historyBlob

check_updateServiceResults = (servicesInfo, currentUrl, urlsResultsCache = null) ->
  #console.log 'yolo 4'
  # if any results from previous tab have not been set, set them.
  if urlsResultsCache? and Object.keys(tempResponsesStore).length > 0
    previousResponsesStore = _.extend {}, tempResponsesStore
    _urlsResultsCache = _.extend {}, urlsResultsCache
    
    kiwi_urlsResultsCache = _save_url_results(servicesInfo, previousResponsesStore, _urlsResultsCache)
    
    
    _save_historyBlob(kiwi_urlsResultsCache, previousResponsesStore.forUrl)
    
  # refresh tempResponsesStore for new url
  tempResponsesStore.forUrl = currentUrl
  tempResponsesStore.services = {}
  
  currentTime = Date.now()
  
  if !urlsResultsCache?
    urlsResultsCache = {}
  if !urlsResultsCache[currentUrl]?
    urlsResultsCache[currentUrl] = {}
  
  # #console.log 'about to check for dispatch query'
  # #console.debug urlsResultsCache[currentUrl]
  
  # check on a service-by-service basis (so we don't requery all services just b/c one api/service is down)
  for service in servicesInfo
    # #console.log 'for service in servicesInfo'
    # #console.debug service
    
    if service.active == 'on'
      if urlsResultsCache[currentUrl][service.name]?
        if (currentTime - urlsResultsCache[currentUrl][service.name].timestamp) > checkForUrlHourInterval * 3600000
          dispatchQuery(service, currentUrl, servicesInfo)
      else
        dispatchQuery(service, currentUrl, servicesInfo)

dispatchQuery = (service_info, currentUrl, servicesInfo) ->
  # console.log 'yolo 5 ~ for ' + service_info.name
  
  currentTime = Date.now()
  
  # self imposed rate limiting per api
  if !serviceQueryTimestamps[service_info.name]?
    serviceQueryTimestamps[service_info.name] = currentTime
  else
    if (currentTime - serviceQueryTimestamps[service_info.name]) < queryThrottleSeconds * 1000
      #wait a couple seconds before querying service
      #console.log 'too soon on dispatch, waiting a couple seconds'
      setTimeout(->
          dispatchQuery(service_info, currentUrl, servicesInfo) 
        , 2000
      )
      return 0
    else
      serviceQueryTimestamps[service_info.name] = currentTime
  
  
  queryObj = {
    url: service_info.queryApi + encodeURIComponent(currentUrl),
    
    onComplete: (queryResult) ->
    #   console.log 'back with'
    #   for key, val of queryResult
    #     console.log key + ' : ' + val
      responsePackage =
        
        forUrl: currentUrl
        
        servicesInfo: servicesInfo
        
        serviceName: service_info.name
        
        queryResult: queryResult.json
      
      setPreppedServiceResults(responsePackage, servicesInfo)
  }
  
  headers = {}
  
  if service_info.name is 'reddit' and firefoxStorage.storage.kiwi_reddit_oauth? 
    #console.log 'we are trying with oauth!'
    #console.debug allItemsInLocalStorage.kiwi_reddit_oauth
    queryObj.headers =
      'Authorization': "'bearer " + firefoxStorage.storage.kiwi_reddit_oauth.token + "'"
      'Content-Type':     'application/x-www-form-urlencoded'
      'X-Requested-With': 'csrf suck it ' + getRandom(1,10000000) # not that the random # matters
  
  # console.log  firefoxStorage.storage.kiwi_productHunt_oauth.token
  if service_info.name is 'productHunt' and firefoxStorage.storage.kiwi_productHunt_oauth? 
    # console.log 'trying PH with'
    # console.debug allItemsInLocalStorage.kiwi_productHunt_oauth
    queryObj.headers =
      'Authorization': "Bearer " + firefoxStorage.storage.kiwi_productHunt_oauth.token
      'Accept': 'application/json'
      'Content-Type': 'application/json'
  Request(queryObj).get()
  
  
dispatchQuery__customSearch = (customSearchQuery, servicesToSearch, service_info, servicesInfo) ->
  #console.log 'yolo 5 ~ for CUSTOM ' + service_info.name
  #console.debug servicesToSearch
  
  currentTime = Date.now()
  
  # self imposed rate limiting per api
  if !serviceQueryTimestamps[service_info.name]?
    serviceQueryTimestamps[service_info.name] = currentTime
  else
    if (currentTime - serviceQueryTimestamps[service_info.name]) < queryThrottleSeconds * 1000
      
      #wait a couple seconds before querying service
      #console.log 'too soon on dispatch, waiting a couple seconds'
      setTimeout(->
          dispatchQuery__customSearch(customSearchQuery, servicesToSearch, service_info, servicesInfo) 
        , 2000
      )
      return 0
    else
      serviceQueryTimestamps[service_info.name] = currentTime
  
  
  
  queryUrl = service_info.customSearchApi + encodeURIComponent(customSearchQuery)
  
  if servicesToSearch[service_info.name].customSearchTags? and Object.keys(servicesToSearch[service_info.name].customSearchTags).length > 0
    
    for tagIdentifier, tagObject of servicesToSearch[service_info.name].customSearchTags
      
      queryUrl = queryUrl + service_info.customSearchTags__convention.string + service_info.customSearchTags[tagIdentifier].string
      
      #console.log 'asd;lfkjaewo;ifjae; '
      # console.log 'for tagIdentifier, tagObject of servicesToSearch[service_info.name].customSearchTags'
      # console.log queryUrl
      # tagObject might one day accept special parameters like author name, etc
      
  queryObj = {
    url: queryUrl,
    
    onComplete: (queryResult) ->
      # console.log 'onComplete: (queryResult) ->'
      # console.log queryResult.json
      responsePackage = {
        
        # forUrl: currentUrl
        
        servicesInfo: servicesInfo
        
        servicesToSearch: servicesToSearch
        customSearchQuery: customSearchQuery
        
        serviceName: service_info.name
        queryResult: queryResult.json
      }
      
      
      setPreppedServiceResults__customSearch(responsePackage, servicesInfo)
  }
  
  headers = {}
  
  if service_info.name is 'reddit' and firefoxStorage.storage.kiwi_reddit_oauth? 
    #console.log 'we are trying with oauth!'
    #console.debug allItemsInLocalStorage.kiwi_reddit_oauth
    queryObj.headers =
      'Authorization': "'bearer " + firefoxStorage.storage.kiwi_reddit_oauth.token + "'"
      'Content-Type':     'application/x-www-form-urlencoded'
      'X-Requested-With': 'csrf suck it ' + getRandom(1,10000000) # not that the random # matters
  
  # console.log 'console.log queryObj monkeybutt'
  # console.log queryObj
  
  Request(queryObj).get()

  
  # proactively set if all service_PreppedResults are ready.
    # will be set with available results if queried by popup.
  
  # the popup should always have enough to render with a properly set popupParcel.
setPreppedServiceResults__customSearch = (responsePackage, servicesInfo) ->
  # console.log 'yolo 6'
  
  currentTime = Date.now()
  
  for serviceObj in servicesInfo
    if serviceObj.name == responsePackage.serviceName
      serviceInfo = serviceObj
  
  
          # responsePackage =
          #   servicesInfo: servicesInfo
          #   serviceName: service_info.name
          #   queryResult: queryResult
          #   servicesToSearch: servicesToSearch  
          #   customSearchQuery: customSearchQuery
          
  # kiwi_customSearchResults = {}  # stores temporarily so if they close popup, they'll still have results
      # maybe it won't clear until new result -- "see last search"
    # queryString
    # servicesSearchesRequested = responsePackage.servicesToSearch
    # servicesSearched
      # <serviceName>
        # results
  
  # even if there are zero matches returned, that counts as a proper query response
  service_PreppedResults = parseResults[responsePackage.serviceName](responsePackage.queryResult, responsePackage.customSearchQuery, serviceInfo, true)
  
  if kiwi_customSearchResults? and kiwi_customSearchResults.queryString? and 
      kiwi_customSearchResults.queryString == responsePackage.customSearchQuery
    kiwi_customSearchResults.servicesSearched[responsePackage.serviceName] = {}
    kiwi_customSearchResults.servicesSearched[responsePackage.serviceName].results = service_PreppedResults
  else
    kiwi_customSearchResults = {}
    kiwi_customSearchResults.queryString = responsePackage.customSearchQuery
    kiwi_customSearchResults.servicesSearchesRequested = responsePackage.servicesToSearch
    kiwi_customSearchResults.servicesSearched = {}
    kiwi_customSearchResults.servicesSearched[responsePackage.serviceName] = {}
    kiwi_customSearchResults.servicesSearched[responsePackage.serviceName].results = service_PreppedResults
    
  
  # console.log 'yolo 6 results service_PreppedResults'
  # console.debug service_PreppedResults
  
  #console.log 'numberOfActiveServices'
  #console.debug returnNumberOfActiveServices(servicesInfo)
  
  numberOfActiveServices = Object.keys(responsePackage.servicesToSearch).length
  
  completedQueryServicesArray = []
  
  
  #number of completed responses
  if kiwi_customSearchResults.queryString == responsePackage.customSearchQuery
    for serviceName, service of kiwi_customSearchResults.servicesSearched
      completedQueryServicesArray.push(serviceName)
    
  completedQueryServicesArray = _.uniq(completedQueryServicesArray)
  
  #console.log 'completedQueryServicesArray.length '
  #console.log completedQueryServicesArray.length
  
  if completedQueryServicesArray.length is numberOfActiveServices and numberOfActiveServices != 0
    
      # NO LONGER STORING URL CACHE IN LOCALSTORAGE - BECAUSE : INFORMATION LEAKAGE / BROKEN EXTENSION SECURITY MODEL
        # get a fresh copy of urls results and reset with updated info
        # chrome.storage.local.get(null, (allItemsInLocalStorage) ->
          # #console.log 'trying to save all'
          # if !allItemsInLocalStorage['kiwi_urlsResultsCache']?
          #   allItemsInLocalStorage['kiwi_urlsResultsCache'] = {}
    
    # console.log 'yolo 6 _save_ results(servicesInfo, tempRes -- for ' + serviceInfo.name
    
    if kiwi_urlsResultsCache[tabUrl]?
      _set_popupParcel(kiwi_urlsResultsCache[tabUrl], tabUrl, true)
    else
      _set_popupParcel({}, tabUrl, true)
    
  # else
  #   #console.log 'yolo 6 not finished ' + serviceInfo.name
  #   _set_popupParcel(tempResponsesStore.services, responsePackage.forUrl, false)
    


_set_popupParcel = (setWith_urlResults, forUrl, sendPopupParcel, renderView = null, oldUrl = false) ->
  # console.log 'monkey butt _set_popupParcel = (setWith_urlResults, forUrl, sendPopupParcel, '
  #console.log 'trying to set popupParcel, forUrl tabUrl' + forUrl + tabUrl
  # tabUrl
  if setWith_urlResults != {}
    if forUrl != tabUrl
      #console.log "_set_popupParcel request for old url"
      return false
  
  setObj_popupParcel = {}
  
  setObj_popupParcel.forUrl = tabUrl
  
  
    
  if !firefoxStorage.storage['kiwi_userPreferences']?
    setObj_popupParcel.kiwi_userPreferences = defaultUserPreferences
    
  else
    setObj_popupParcel.kiwi_userPreferences = firefoxStorage.storage['kiwi_userPreferences']
  
  if !firefoxStorage.storage['kiwi_servicesInfo']?
    setObj_popupParcel.kiwi_servicesInfo = defaultServicesInfo
    
  else
    setObj_popupParcel.kiwi_servicesInfo = firefoxStorage.storage['kiwi_servicesInfo']
  
  if renderView != null
    setObj_popupParcel.view = renderView
  
  if !firefoxStorage.storage['kiwi_alerts']?
  
    setObj_popupParcel.kiwi_alerts = []
    
  else
    setObj_popupParcel.kiwi_alerts = firefoxStorage.storage['kiwi_alerts']
    
  setObj_popupParcel.kiwi_customSearchResults = kiwi_customSearchResults
  
  if !setWith_urlResults?
    #console.log '_set_popupParcel called with undefined responses (not supposed to happen, ever)'
    return 0
  else
    setObj_popupParcel.allPreppedResults = setWith_urlResults
  
  if tabUrl == forUrl
    setObj_popupParcel.tabInfo = {} 
    setObj_popupParcel.tabInfo.tabUrl = tabUrl
    setObj_popupParcel.tabInfo.tabTitle = tabTitleObject.tabTitle
  else 
    setObj_popupParcel.tabInfo = null
  
  setObj_popupParcel.urlBlocked = false
  
  isUrlBlocked = is_url_blocked(firefoxStorage.storage['kiwi_userPreferences'].urlSubstring_blacklists, tabUrl)
  if isUrlBlocked == true
    setObj_popupParcel.urlBlocked = true
  
  if oldUrl is true
    setObj_popupParcel.oldUrl = true
  else
    setObj_popupParcel.oldUrl = false
  
  popupParcel = setObj_popupParcel
  
  
  
  if sendPopupParcel
    
    parcel = {}
    
    parcel.msg = 'kiwiPP_popupParcel_ready'
    parcel.forUrl = tabUrl
    
    parcel.popupParcel = setObj_popupParcel
    
    sendParcel(parcel)
  

setPreppedServiceResults = (responsePackage, servicesInfo) ->
  
  currentTime = Date.now()
  
  # if tabUrl == responsePackage.forUrl  # if false, then do nothing (user's probably switched to new tab)
    
  for serviceObj in servicesInfo
    if serviceObj.name == responsePackage.serviceName
      serviceInfo = serviceObj
      
  # serviceInfo = servicesInfo[responsePackage.serviceName]
  
  
  # even if there are zero matches returned, that counts as a proper query response
  service_PreppedResults = parseResults[responsePackage.serviceName](responsePackage.queryResult, tabUrl, serviceInfo)
  
  if !tempResponsesStore.services?
    tempResponsesStore = {}
    tempResponsesStore.services = {}
  
  tempResponsesStore.services[responsePackage.serviceName] =
    
    timestamp: currentTime
    service_PreppedResults: service_PreppedResults
    forUrl: tabUrl
  
  #console.log 'yolo 6 results service_PreppedResults'
  #console.debug service_PreppedResults
  
  #console.log 'numberOfActiveServices'
  #console.debug returnNumberOfActiveServices(servicesInfo)
  
  numberOfActiveServices = returnNumberOfActiveServices(servicesInfo)
  
  completedQueryServicesArray = []
  
  #number of completed responses
  if tempResponsesStore.forUrl == tabUrl
    for serviceName, service of tempResponsesStore.services
      completedQueryServicesArray.push(serviceName)
      
  if kiwi_urlsResultsCache[tabUrl]?
    for serviceName, service of kiwi_urlsResultsCache[tabUrl]
      completedQueryServicesArray.push(serviceName)
    
  completedQueryServicesArray = _.uniq(completedQueryServicesArray)
  
  if completedQueryServicesArray.length is numberOfActiveServices and numberOfActiveServices != 0
    
      # NO LONGER STORING URL CACHE IN LOCALSTORAGE - BECAUSE 1.) INFORMATION LEAKAGE, 2.) SLOWER
        # get a fresh copy of urls results and reset with updated info
        # chrome.storage.local.get(null, (allItemsInLocalStorage) ->
          # #console.log 'trying to save all'
          # if !allItemsInLocalStorage['kiwi_urlsResultsCache']?
          #   allItemsInLocalStorage['kiwi_urlsResultsCache'] = {}
    
    #console.log 'yolo 6 _save_url_results(servicesInfo, tempRes -- for ' + serviceInfo.name
    
    kiwi_urlsResultsCache = _save_url_results(servicesInfo, tempResponsesStore, kiwi_urlsResultsCache)
    
    _save_historyBlob(kiwi_urlsResultsCache, tabUrl)
    
    _set_popupParcel(kiwi_urlsResultsCache[tabUrl], tabUrl, true)
    refreshBadge(servicesInfo, kiwi_urlsResultsCache[tabUrl])
    
  else
    #console.log 'yolo 6 not finished ' + serviceInfo.name
    _set_popupParcel(tempResponsesStore.services, tabUrl, false)
    refreshBadge(servicesInfo, tempResponsesStore.services)





    
  
  
#returns an array of 'preppedResults' for url - just the keys we care about from the query-response
parseResults =
  
  productHunt: (resultsObj, searchQueryString, serviceInfo, customSearchBool = false) ->
    # console.log 'resultsObj'
    # console.log 'for: ' + searchQueryString
    # console.debug resultsObj
    
    # console.log 'customSearchBool ' + customSearchBool
    # console.log resultsObj.posts
    matchedListings = []
    if customSearchBool is false # so, normal URL-based queries
      
        # created_at: "2014-08-18T06:40:47.000-07:00"
        # discussion_url: "http://www.producthunt.com/tech/product-hunt-api-beta"

        # comments_count: 13
        # votes_count: 514
        # name: "Product Hunt API (beta)"

        # featured: true

        # id: 6970

        # maker_inside: true

        # tagline: "Make stuff with us. Signup for early access to the PH API :)"

        # user:
        #   headline: "Tech at Product Hunt 💃"
        #   profile_url: "http://www.producthunt.com/@andreasklinger"
        #   name: "Andreas Klinger"
        #   username: "andreasklinger"
        #   website_url: "http://klinger.io"
        
      if resultsObj.posts? and _.isArray(resultsObj.posts) is true
        
        for post in resultsObj.posts
          
          listingKeys = [
            'created_at','discussion_url','comments_count','redirect_url','votes_count','name',
            'featured','id','user','screenshot_url','tagline','maker_inside','makers'
          ]
          
          preppedResult = _.pick(post, listingKeys)
          
          preppedResult.kiwi_created_at = Date.parse(preppedResult.created_at)
          
          preppedResult.kiwi_discussion_url = preppedResult.discussion_url
          
          if preppedResult.user? and preppedResult.user.name? 
            preppedResult.kiwi_author_name = preppedResult.user.name.trim()
          else
            preppedResult.kiwi_author_name = ""
          
          if preppedResult.user? and preppedResult.user.username? 
            preppedResult.kiwi_author_username = preppedResult.user.username
          else
            preppedResult.kiwi_author_username = ""
            
          if preppedResult.user? and preppedResult.user.headline?
            preppedResult.kiwi_author_headline = preppedResult.user.headline.trim()
          else
            preppedResult.kiwi_author_headline = ""
          
          preppedResult.kiwi_makers = []
          
          for maker, index in post.makers
            makerObj = {}
            makerObj.headline = maker.headline
            makerObj.name = maker.name
            makerObj.username = maker.username
            makerObj.profile_url = maker.profile_url
            makerObj.website_url = maker.website_url
            
            preppedResult.kiwi_makers.push makerObj
          
          
          preppedResult.kiwi_exact_match = true # PH won't return fuzzy matches
          
          preppedResult.kiwi_score = preppedResult.votes_count
          preppedResult.kiwi_num_comments = preppedResult.comments_count
          preppedResult.kiwi_permaId = preppedResult.permalink
          
          matchedListings.push preppedResult
    else # custom string queries
    
        # comment_count
        # vote_count
        
        # name
        
        # url # 
        
        # tagline
          
        # category
        #   tech
        
        
        # product_makers
        #   headline
        #   name
        #   username
        #   is_maker
      
      # console.log ' else # custom string queries ' + _.isArray(resultsObj) # 
      if resultsObj? and _.isArray(resultsObj)
        # console.log ' yoyoyoy1 '
        for searchMatch in resultsObj
          
          listingKeys = [
            'author'
            'url',
            'tagline',
            'product_makers'
            'comment_count',
            'vote_count',
            'name',
            
            'id',
            'user',
            'screenshot_url',
            
          ]
          
          preppedResult = _.pick(searchMatch, listingKeys)
          
          preppedResult.kiwi_created_at = null  # algolia doesn't provide created at value :<
          
          preppedResult.kiwi_discussion_url = "http://www.producthunt.com/" + preppedResult.url
          
          if preppedResult.author? and preppedResult.author.name? 
            preppedResult.kiwi_author_name = preppedResult.author.name.trim()
          else
            preppedResult.kiwi_author_name = ""
          
          if preppedResult.author? and preppedResult.author.username? 
            preppedResult.kiwi_author_username = preppedResult.author.username
          else
            preppedResult.kiwi_author_username = ""
            
          if preppedResult.author? and preppedResult.author.headline?
            preppedResult.kiwi_author_headline = preppedResult.author.headline.trim()
          else
            preppedResult.kiwi_author_headline = ""
          
          preppedResult.kiwi_makers = []
          
          for maker, index in searchMatch.product_makers
            makerObj = {}
            makerObj.headline = maker.headline
            makerObj.name = maker.name
            makerObj.username = maker.username
            makerObj.profile_url = maker.profile_url
            makerObj.website_url = maker.website_url
            
            preppedResult.kiwi_makers.push makerObj
          
          preppedResult.kiwi_exact_match = true # PH won't return fuzzy matches
          
          preppedResult.kiwi_score = preppedResult.vote_count
          preppedResult.kiwi_num_comments = preppedResult.comment_count
          preppedResult.kiwi_permaId = preppedResult.permalink
          
          
          matchedListings.push preppedResult
      
    return matchedListings
  
  reddit: (resultsObj, searchQueryString, serviceInfo, customSearchBool = false) ->
    
    matchedListings = []
    # console.log 'reddit: (resultsObj) ->'
    # console.debug resultsObj
    
    # occasionally Reddit will decide to return an array instead of an object, so...
      # in response to user's feedback, see: https://news.ycombinator.com/item?id=9994202
    forEachQueryObject = (resultsObj, _matchedListings) ->
    
      if resultsObj.kind? and resultsObj.kind == "Listing" and resultsObj.data? and 
          resultsObj.data.children? and resultsObj.data.children.length > 0
        
        for child in resultsObj.data.children
          
          if child.data? and child.kind? and child.kind == "t3"
            
            listingKeys = ["subreddit",'url',"score",'domain','gilded',"over_18","author","hidden","downs","permalink","created","title","created_utc","ups","num_comments"]
            
            preppedResult = _.pick(child.data, listingKeys)
            
            preppedResult.kiwi_created_at = preppedResult.created_utc * 1000 # to normalize to JS's Date.now() millisecond UTC timestamp
            
            if customSearchBool is false
              preppedResult.kiwi_exact_match = _exact_match_url_check(searchQueryString, preppedResult.url)
            else
              preppedResult.kiwi_exact_match = true
            
            preppedResult.kiwi_score = preppedResult.score
            
            preppedResult.kiwi_permaId = preppedResult.permalink
            
            _matchedListings.push preppedResult
      
      return _matchedListings
    
    if _.isArray(resultsObj)
      
      for result in resultsObj
        matchedListings = forEachQueryObject(result, matchedListings)
      
    else
      matchedListings = forEachQueryObject(resultsObj, matchedListings)
    
    return matchedListings
      
    
  hackerNews: (resultsObj, searchQueryString, serviceInfo, customSearchBool = false) ->
    
    matchedListings = []
    #console.log ' hacker news #console.debug resultsObj'
    #console.debug resultsObj
    # if resultsObj.nbHits? and resultsObj.nbHits > 0 and resultsObj.hits? and resultsObj.hits.length is resultsObj.nbHits
    if resultsObj? and resultsObj.hits?
      for hit in resultsObj.hits
        
        listingKeys = ["points","num_comments","objectID","author","created_at","title","url","created_at_i"
              "story_text","comment_text","story_id","story_title","story_url"
            ]
        preppedResult = _.pick(hit, listingKeys)
        
        preppedResult.kiwi_created_at = preppedResult.created_at_i * 1000 # to normalize to JS's Date.now() millisecond UTC timestamp
        
        if customSearchBool is false
          preppedResult.kiwi_exact_match = _exact_match_url_check(searchQueryString, preppedResult.url)
        else
          preppedResult.kiwi_exact_match = true
        
        preppedResult.kiwi_score = preppedResult.points
        
        preppedResult.kiwi_permaId = preppedResult.objectID
        
        matchedListings.push preppedResult
      
    return matchedListings
  
  gnews: (resultsObj, searchQueryString, serviceInfo, customSearchBool = false) ->
    
    if customSearchBool == false
      forUrl = searchQueryString
      matchedListings = []
      #console.log 'gnews: (resultsObj) ->'
      #console.debug resultsObj
      
      for child in resultsObj
        
        
        listingKeys = ['clusterUrl','publisher','content','publishedDate','unescapedUrl','titleNoFormatting']
        
        preppedResult = _.pick(child, listingKeys)
        
        preppedResult.kiwi_created_at = Date.parse(preppedResult.publishedDate)
        
        preppedResult.kiwi_exact_match = false # impossible to know what's an exact match with gnews results
        
        preppedResult.kiwi_score = null
        
        preppedResult.kiwi_permaId = preppedResult.unescapedUrl
        
        if customSearchBool is false
              preppedResult.kiwi_exact_match = _exact_match_url_check(forUrl, preppedResult.url)
            else
              preppedResult.kiwi_exact_match = true
        preppedResult.kiwi_searchedFor = tabTitleObject.tabTitle
        
        if preppedResult.unescapedUrl != forUrl
          matchedListings.push preppedResult
          
        else if preppedResult.clusterUrl != ''
          matchedListings.push preppedResult
          
        
      currentTime = Date.now()
      
      # hacky, whatever
      noteworthy = false
      __numberOfStoriesFoundWithinTheHoursSincePostedLimit = 0
      __numberOfRelatedItemsWithClusterURL = 0
      
      for listing in matchedListings
        
          
        if listing.clusterUrl? and listing.clusterUrl != ''
          __numberOfRelatedItemsWithClusterURL++
          
        if (currentTime - listing.kiwi_created_at) < serviceInfo.notableConditions.hoursSincePosted * 3600000
          __numberOfStoriesFoundWithinTheHoursSincePostedLimit++
          
      
      if __numberOfStoriesFoundWithinTheHoursSincePostedLimit >= serviceInfo.notableConditions.numberOfStoriesFoundWithinTheHoursSincePostedLimit
        noteworthy = true
        
      if __numberOfRelatedItemsWithClusterURL >= serviceInfo.notableConditions.numberOfRelatedItemsWithClusterURL
        noteworthy = true
        
      if noteworthy
        matchedListings[0].kiwi_exact_match = true
      
      
      #console.log '#console.debug __numberOfStoriesFoundWithinTheHoursSincePostedLimit
      #console.debug serviceInfo.notableConditions.numberOfStoriesFoundWithinTheHoursSincePostedLimit'
      #console.debug __numberOfRelatedItemsWithClusterURL
      #console.debug serviceInfo.notableConditions.numberOfRelatedItemsWithClusterURL
      
      return matchedListings
    else
      matchedListings = []
      #console.log 'gnews: (resultsObj) ->'
      #console.debug resultsObj
      
      for child in resultsObj
        
        listingKeys = ['clusterUrl','publisher','content','publishedDate','unescapedUrl','titleNoFormatting']
        
        preppedResult = _.pick(child, listingKeys)
        
        preppedResult.kiwi_created_at = Date.parse(preppedResult.publishedDate)
        
        preppedResult.kiwi_exact_match = false # impossible to know what's an exact match with gnews results
        
        preppedResult.kiwi_score = null
        
        preppedResult.kiwi_permaId = preppedResult.unescapedUrl
        
        preppedResult.kiwi_searchedFor = searchQueryString
        
        preppedResult.kiwi_exact_match = false
        
        matchedListings.push preppedResult
        
      return matchedListings

_exact_match_url_check = (forUrl, preppedResultUrl) ->
  
    # warning:: one of the worst algo-s i've ever written... please don't use as reference
  
  kiwi_exact_match = false
  
  modifications = [
    
      name: 'trailingSlash'
      modify: (tOrF, forUrl) ->
        
        if tOrF is 't'
          if forUrl[forUrl.length - 1] != '/'
            trailingSlashURL = forUrl + '/'
          else
            trailingSlashURL = forUrl
          return trailingSlashURL
        else
          if forUrl[forUrl.length - 1] == '/'
            noTrailingSlashURL = forUrl.substr(0,forUrl.length - 1)
          else
            noTrailingSlashURL = forUrl
          return noTrailingSlashURL
        # if forUrl[forUrl.length - 1] == '/'
  #   noTrailingSlashURL = forUrl.substr(0,forUrl.length - 1)
        
      existsTest: (forUrl) ->
        if forUrl[forUrl.length - 1] == '/'
          return 't'
        else
          return 'f'
    ,
      name: 'www'
      modify: (tOrF, forUrl) ->
        if tOrF is 't'
          protocolSplitUrlArray = forUrl.split('://')
          if protocolSplitUrlArray.length > 1
            if protocolSplitUrlArray[1].indexOf('www.') != 0
              protocolSplitUrlArray[1] = 'www.' + protocolSplitUrlArray[1]
              WWWurl = protocolSplitUrlArray.join('://')
            else
              WWWurl = forUrl
            return WWWurl
            
          else
            if protocolSplitUrlArray[0].indexOf('www.') != 0
              protocolSplitUrlArray[0] = 'www.' + protocolSplitUrlArray[1]
              WWWurl = protocolSplitUrlArray.join('://')
            else
              WWWurl = forUrl
            return WWWurl
        else
          wwwSplitUrlArray = forUrl.split('www.')
          if wwwSplitUrlArray.length is 2
            noWWWurl = wwwSplitUrlArray.join('')
            
          else if wwwSplitUrlArray.length > 2
            noWWWurl = wwwSplitUrlArray.shift() 
            noWWWurl += wwwSplitUrlArray.shift()
            noWWWurl += wwwSplitUrlArray.join('www.')
          else
            noWWWurl = forUrl
          return noWWWurl
      existsTest: (forUrl) ->
        if forUrl.split('//www.').length > 0
          return 't'
        else
          return 'f'
    ,
      name:'http'
      existsTest: (forUrl) ->
        if forUrl.indexOf('http://') is 0
          return 't'
        else
          return 'f'
      modify: (tOrF, forUrl) ->
        if tOrF is 't'
          if forUrl.indexOf('https://') == 0
            HTTPurl = 'http://' + forUrl.substr(8, forUrl.length - 1)
          else
            HTTPurl = forUrl
        else
          if forUrl.indexOf('http://') == 0
            HTTPSurl = 'https://' + forUrl.substr(7, forUrl.length - 1)
          else
            HTTPSurl = forUrl
          
    ]
  
  modPermutations = {}
  
  forUrlUnmodded = ''
  for mod in modifications
    forUrlUnmodded += mod.existsTest(forUrl)
  
  modPermutations[forUrlUnmodded] = forUrl
  
  existStates = ['t','f']
  for existState in existStates
    
    for mod, index in modifications
      checkArray = []
      for m in modifications
        checkArray.push existState
      
      forUrl_ = modifications[index].modify(existState, forUrl)
      
      for existState_ in existStates
        
        checkArray[index] = existState_
        
        for mod_, index_ in modifications
          
          if index != index_
            
            for existState__ in existStates
              
              checkArray[index_] = existState__
              checkString = checkArray.join('')
              
              if !modPermutations[checkString]?
                altUrl = forUrl_
                for existState_Char, cSindex in checkString
                  altUrl = modifications[cSindex].modify(existState_Char, altUrl)
                
                modPermutations[checkString] = altUrl
                
  kiwi_exact_match = false
  if preppedResultUrl == forUrl
    kiwi_exact_match = true
  for modKey, moddedUrl of modPermutations
    
    if preppedResultUrl == moddedUrl
      kiwi_exact_match = true
  
  return kiwi_exact_match

refreshBadge = (servicesInfo, resultsObjForCurrentUrl) ->
  
  # #console.log 'yolo 8'
  # #console.debug resultsObjForCurrentUrl
  # #console.debug servicesInfo
  
  # icon badges typically only have room for 5 characters
  
  currentTime = Date.now()
  
  abbreviationLettersArray = []
  
  for service, index in servicesInfo
    # if resultsObjForCurrentUrl[service.name]
  
    if resultsObjForCurrentUrl[service.name]? and resultsObjForCurrentUrl[service.name].service_PreppedResults.length > 0
      
      exactMatch = false
      noteworthy = false
      for listing in resultsObjForCurrentUrl[service.name].service_PreppedResults
        if listing.kiwi_exact_match
          exactMatch = true
          if listing.num_comments? and listing.num_comments >= service.notableConditions.num_comments
            noteworthy = true
            break
          if (currentTime - listing.kiwi_created_at) < service.notableConditions.hoursSincePosted * 3600000
            noteworthy = true
            break
      
      
      if service.updateBadgeOnlyWithExactMatch and exactMatch = false
        break
      
      #console.log service.name + ' noteworthy ' + noteworthy
      
      if noteworthy
        abbreviationLettersArray.push service.abbreviation
      else
        abbreviationLettersArray.push service.abbreviation.toLowerCase()
      #console.debug abbreviationLettersArray
        
  badgeText = ''
  if abbreviationLettersArray.length == 0
    if firefoxStorage.storage.kiwi_userPreferences? and firefoxStorage.storage['kiwi_userPreferences'].researchModeOnOff == 'off'
      badgeText = ''
    else if defaultUserPreferences.researchModeOnOff == 'off'
      badgeText = ''
    else
      badgeText = ''
  else
    badgeText = abbreviationLettersArray.join(" ")
    
  #console.log 'yolo 8 ' + badgeText
  
  updateBadgeText(badgeText)
  
  



periodicCleanup = (tab, initialize_callback) ->
  #console.log 'wtf a'
  currentTime = Date.now()
  
  if(last_periodicCleanup < (currentTime - CLEANUP_INTERVAL))
    
    last_periodicCleanup = currentTime
    
    #console.log 'wtf b'
    # delete any results older than checkForUrlHourInterval 
    
    if Object.keys(kiwi_urlsResultsCache).length is 0
      #console.log 'wtf ba'
      # nothing to (potentially) clean up!
      initialize_callback(tab)
      
    else
      #console.log 'wtf bb'
      # allItemsInLocalStorage.kiwi_urlsResultsCache
      
      cull_kiwi_urlsResultsCache = _.extend {}, kiwi_urlsResultsCache
      
      for url, urlServiceResults of cull_kiwi_urlsResultsCache
        for serviceKey, serviceResults of urlServiceResults
          if currentTime - serviceResults.timestamp > checkForUrlHourInterval
            delete kiwi_urlsResultsCache[url]
      
      if Object.keys(kiwi_urlsResultsCache).length > maxUrlResultsStoredInLocalStorage
        
        # you've been surfing! wow
        
        num_results_to_delete = Object.keys(kiwi_urlsResultsCache).length - maxUrlResultsStoredInLocalStorage
        
        deletedCount = 0
        
        cull_kiwi_urlsResultsCache = _.extend {}, kiwi_urlsResultsCache
        
        for url, urlServiceResults of cull_kiwi_urlsResultsCache
          if deleteCount >= num_results_to_delete
            break
          
          if url != tab.url
            
            delete kiwi_urlsResultsCache[url]
            
            deletedCount++
        
        # chrome.storage.local.set({'kiwi_urlsResultsCache':kiwi_urlsResultsCache}, ->
            
        initialize_callback(tab)
          
        # )
      else
        initialize_callback(tab)
    
  else
    #console.log 'wtf c'
    initialize_callback(tab)

_save_from_popupParcel = (_popupParcel, forUrl, updateToView) ->
  
  formerResearchModeValue = null
  formerKiwi_servicesInfo = null
  former_autoOffTimerType = null
  former_autoOffTimerValue = null
  
  # #console.log '#console.debug popupParcel
  #  #console.debug _popupParcel'
  
  # #console.debug popupParcel
  # #console.debug _popupParcel
  
  if popupParcel? and popupParcel.kiwi_userPreferences? and popupParcel.kiwi_servicesInfo
    formerResearchModeValue = popupParcel.kiwi_userPreferences.researchModeOnOff
    formerKiwi_servicesInfo = popupParcel.kiwi_servicesInfo
    former_autoOffTimerType = popupParcel.kiwi_userPreferences.autoOffTimerType
    former_autoOffTimerValue = popupParcel.kiwi_userPreferences.autoOffTimerValue
  
  popupParcel = {}
  
  # #console.log ' asdfasdfasd formerKiwi_autoOffTimerType'
  # #console.log former_autoOffTimerType
  # #console.log _popupParcel.kiwi_userPreferences.autoOffTimerType
  # #console.log ' a;woeifjaw;ef formerKiwi_autoOffTimerValue'
  # #console.log former_autoOffTimerValue
  # #console.log _popupParcel.kiwi_userPreferences.autoOffTimerValue
  
  if formerResearchModeValue? and formerResearchModeValue == 'off' and 
      _popupParcel.kiwi_userPreferences? and _popupParcel.kiwi_userPreferences.researchModeOnOff == 'on' or 
      (former_autoOffTimerType != _popupParcel.kiwi_userPreferences.autoOffTimerType or
      former_autoOffTimerValue != _popupParcel.kiwi_userPreferences.autoOffTimerValue)
    
    resetTimerBool = true
  else
    resetTimerBool = false
  
  _autoOffAtUTCmilliTimestamp = setAutoOffTimer(resetTimerBool, _popupParcel.kiwi_userPreferences.autoOffAtUTCmilliTimestamp, 
      _popupParcel.kiwi_userPreferences.autoOffTimerValue, _popupParcel.kiwi_userPreferences.autoOffTimerType, 
      _popupParcel.kiwi_userPreferences.researchModeOnOff)
  
  _popupParcel.kiwi_userPreferences.autoOffAtUTCmilliTimestamp = _autoOffAtUTCmilliTimestamp
  
  
  firefoxStorage.storage.kiwi_userPreferences = _popupParcel.kiwi_userPreferences
  
  firefoxStorage.storage.kiwi_servicesInfo = _popupParcel.kiwi_servicesInfo
  
              
  if updateToView?
    
    parcel = {}
    
    _popupParcel['view'] = updateToView
    
    popupParcel = _popupParcel
    parcel.msg = 'kiwiPP_popupParcel_ready'
    parcel.forUrl = tabUrl
    parcel.popupParcel = _popupParcel
    
    sendParcel(parcel)
  
  #console.log 'in _save_from_popupParcel _popupParcel.forUrl ' + _popupParcel.forUrl
  #console.log 'in _save_from_popupParcel tabUrl ' + tabUrl
  if _popupParcel.forUrl == tabUrl
    
    
    if formerResearchModeValue? and formerResearchModeValue == 'off' and 
        _popupParcel.kiwi_userPreferences? and _popupParcel.kiwi_userPreferences.researchModeOnOff == 'on'
      
      initIfNewURL(true); return 0
    else if formerKiwi_servicesInfo? 
      # so if user turns on a service and saves - it will immediately begin new query
      formerActiveServicesList = _.pluck(formerKiwi_servicesInfo, 'active')
      newActiveServicesList = _.pluck(_popupParcel.kiwi_servicesInfo, 'active')
      #console.log 'formerActiveServicesList = _.pluck(formerKiwi_servicesInfo)'
      #console.debug formerActiveServicesList
      #console.log 'newActiveServicesList = _.pluck(_popupParcel.kiwi_servicesInfo)'
      #console.debug newActiveServicesList
      
      if !_.isEqual(formerActiveServicesList, newActiveServicesList)
        initIfNewURL(true); return 0
      else
        refreshBadge(_popupParcel.kiwi_servicesInfo, _popupParcel.allPreppedResults); return 0
    else
      refreshBadge(_popupParcel.kiwi_servicesInfo, _popupParcel.allPreppedResults); return 0
    
  
setAutoOffTimer = (resetTimerBool, autoOffAtUTCmilliTimestamp, autoOffTimerValue, autoOffTimerType, researchModeOnOff) ->
  #console.log 'trying setAutoOffTimer 43234'
  
  if resetTimerBool and kiwi_autoOffClearInterval?
    #console.log 'clearing timout'
    clearTimeout(kiwi_autoOffClearInterval)
    kiwi_autoOffClearInterval = null
  
    
  currentTime = Date.now()
  
  new_autoOffAtUTCmilliTimestamp = null
  
  if researchModeOnOff == 'on'
    if autoOffAtUTCmilliTimestamp == null || resetTimerBool
      
        
      if autoOffTimerType == '20'
        new_autoOffAtUTCmilliTimestamp = currentTime + 20 * 60 * 1000
      else if autoOffTimerType == '60'
        new_autoOffAtUTCmilliTimestamp = currentTime + 60 * 60 * 1000
      else if autoOffTimerType == 'always'
        new_autoOffAtUTCmilliTimestamp = null
      else if autoOffTimerType == 'custom'
        new_autoOffAtUTCmilliTimestamp = currentTime + parseInt(autoOffTimerValue) * 60 * 1000
        #console.log 'setting custom new_autoOffAtUTCmilliTimestamp ' + new_autoOffAtUTCmilliTimestamp
        
    else
      
      new_autoOffAtUTCmilliTimestamp = autoOffAtUTCmilliTimestamp
      
      if !kiwi_autoOffClearInterval? and autoOffAtUTCmilliTimestamp > currentTime
        #console.log 'resetting timer timeout'
        
        kiwi_autoOffClearInterval = setTimeout( ->
            turnResearchModeOff()
          , new_autoOffAtUTCmilliTimestamp - currentTime )
      
      #console.log ' setting 123 autoOffAtUTCmilliTimestamp ' + new_autoOffAtUTCmilliTimestamp
      
      return new_autoOffAtUTCmilliTimestamp
  else
    # it's already off - no need for timer
    new_autoOffAtUTCmilliTimestamp = null
    
    #console.log 'researchModeOnOff is off - resetting autoOff timestamp and clearInterval'
    
    if kiwi_autoOffClearInterval?
      clearTimeout(kiwi_autoOffClearInterval)
      kiwi_autoOffClearInterval = null
  
  #console.log ' setting 000 autoOffAtUTCmilliTimestamp ' + new_autoOffAtUTCmilliTimestamp
  
  if new_autoOffAtUTCmilliTimestamp != null
    #console.log 'setting timer timeout'
    kiwi_autoOffClearInterval = setTimeout( ->
        turnResearchModeOff()
      , new_autoOffAtUTCmilliTimestamp - currentTime )
  
  return new_autoOffAtUTCmilliTimestamp
    
turnResearchModeOff = ->
  #console.log 'turning off research mode - in turnResearchModeOff'
  
  # chrome.storage.sync.get(null, (allItemsInSyncedStorage) -> )
  
  if kiwi_urlsResultsCache[tabUrl]?
    urlResults = kiwi_urlsResultsCache[tabUrl]
  else
    urlResults = {}
  
  if firefoxStorage.storage.kiwi_userPreferences?
    
    firefoxStorage.storage.kiwi_userPreferences.researchModeOnOff = 'off'
    firefoxStorage.storage['kiwi_userPreferences'] = firefoxStorage.storage.kiwi_userPreferences
    _set_popupParcel(urlResults, tabUrl, true)
    if firefoxStorage.storage.kiwi_servicesInfo?
      refreshBadge(firefoxStorage.storage.kiwi_servicesInfo, urlResults)
    
  else
    defaultUserPreferences.researchModeOnOff = 'off'
    
    firefoxStorage.storage['kiwi_userPreferences'] = defaultUserPreferences
        
    _set_popupParcel(urlResults, tabUrl, true)
    
    if firefoxStorage.storage.kiwi_servicesInfo?
      
      refreshBadge(firefoxStorage.storage.kiwi_servicesInfo, urlResults)   
      
autoOffTimerExpired_orResearchModeOff_withoutURLoverride = (currentTime, overrideResearchModeOff, tabUrl, kiwi_urlsResultsCache) ->
  if firefoxStorage.storage.kiwi_userPreferences?
    
    if firefoxStorage.storage.kiwi_userPreferences.autoOffAtUTCmilliTimestamp?
      if currentTime > firefoxStorage.storage.kiwi_userPreferences.autoOffAtUTCmilliTimestamp 
        #console.log 'timer is past due - turning off - in initifnewurl'
        firefoxStorage.storage.kiwi_userPreferences.researchModeOnOff = 'off'
        
    if firefoxStorage.storage.kiwi_userPreferences.researchModeOnOff is 'off' and overrideResearchModeOff == false
      updateBadgeText('') # off
      
      return true
  
  
  return false

proceedWithPreInitCheck =  (overrideSameURLCheck_popupOpen, 
    overrideResearchModeOff, sameURLCheck, tabUrl, currentTime, popupOpen) ->
  
  if firefoxStorage.storage['kiwi_userPreferences']? and overrideResearchModeOff is false
    # overrideResearchModeOff = is_url_whitelisted(firefoxStorage.storage['kiwi_userPreferences'].urlSubstring_whitelists, tabUrl)
    
    isUrlWhitelistedBool = is_url_whitelisted(firefoxStorage.storage['kiwi_userPreferences'].urlSubstring_whitelists, tabUrl)
    
      # provided that the user isn't specifically researching a URL, if it's whitelisted, then that acts as override
    overrideResearchModeOff = isUrlWhitelistedBool
    
  
  
  if autoOffTimerExpired_orResearchModeOff_withoutURLoverride(currentTime, overrideResearchModeOff, tabUrl, kiwi_urlsResultsCache) is true
    # show cached responses, if present
      
      #console.log 'if tabUrl == tempResponsesStore.forUrl'
      #console.log tabUrl
      #console.log tempResponsesStore.forUrl
      
    if kiwi_urlsResultsCache[tabUrl]?
      _set_popupParcel(kiwi_urlsResultsCache[tabUrl],tabUrl,false);
      if firefoxStorage.storage['kiwi_servicesInfo']?
        refreshBadge(firefoxStorage.storage['kiwi_servicesInfo'], kiwi_urlsResultsCache[tabUrl])
    else
      
      _set_popupParcel({},tabUrl,true); 
  else
    
    periodicCleanup(tabUrl, (tabUrl) ->
      
      #console.log 'in initialize callback'
      
      if !firefoxStorage.storage['kiwi_userPreferences']?
        
        # defaultUserPreferences 
        
        #console.log "#console.debug allItemsInSyncedStorage['kiwi_userPreferences']"
        #console.debug allItemsInSyncedStorage['kiwi_userPreferences']
        
        _autoOffAtUTCmilliTimestamp = setAutoOffTimer(false, defaultUserPreferences.autoOffAtUTCmilliTimestamp, 
            defaultUserPreferences.autoOffTimerValue, defaultUserPreferences.autoOffTimerType, defaultUserPreferences.researchModeOnOff)
        
        defaultUserPreferences.autoOffAtUTCmilliTimestamp = _autoOffAtUTCmilliTimestamp
        
        # setObj =
        #   kiwi_servicesInfo: defaultServicesInfo
        #   kiwi_userPreferences: defaultUserPreferences
        
        firefoxStorage.storage.kiwi_servicesInfo = defaultServicesInfo
        firefoxStorage.storage.kiwi_userPreferences = defaultUserPreferences
        
        # chrome.storage.sync.set(setObj, -> )
        
        isUrlBlocked = is_url_blocked(defaultUserPreferences.urlSubstring_blacklists, tabUrl)
        if isUrlBlocked == true and overrideResearchModeOff == false
          
          # user is not interested in results for this url
          updateBadgeText('block')
          #console.log '# user is not interested in results for this url: ' + tabUrl
          
          _set_popupParcel({}, tabUrl, true)  # trying to send, because options page
          
          return 0 # we return before initializing script
          
        initialize(tabUrl)
        
      else
        #console.log "allItemsInSyncedStorage['kiwi_userPreferences'].urlSubstring_blacklists"
        #console.debug allItemsInSyncedStorage['kiwi_userPreferences'].urlSubstring_blacklists
        
        isUrlBlocked = is_url_blocked(firefoxStorage.storage['kiwi_userPreferences'].urlSubstring_blacklists, tabUrl)
        
        if isUrlBlocked == true and overrideResearchModeOff == false
          
          # user is not interested in results for this url
          updateBadgeText('block')
          #console.log '# user is not interested in results for this url: ' + tabUrl
          _set_popupParcel({}, tabUrl, true)  # trying to send, because options page
          
          return 0 # we return/cease before initializing script
            
        initialize(tabUrl)
    )

checkForNewDefaultUserPreferenceAttributes_thenProceedWithInitCheck = (overrideSameURLCheck_popupOpen, 
            overrideResearchModeOff, sameURLCheck, tabUrl, currentTime, popupOpen) ->
  
    # ^^ checks if newly added default user preference attributes exist (so new features don't break current installs)
  setObj = {}
  newUserPrefsAttribute = false
  newServicesInfoAttribute = false
  newServicesInfo = []
  newUserPreferences = {}
  
  if firefoxStorage.storage['kiwi_userPreferences']?
    
    newUserPreferences = _.extend {}, firefoxStorage.storage['kiwi_userPreferences']
    
    for keyName, value of defaultUserPreferences
      
      if typeof firefoxStorage.storage['kiwi_userPreferences'][keyName] is 'undefined'
        # console.log 'the following is a new keyName '
        # console.log keyName
        newUserPrefsAttribute = true
        newUserPreferences[keyName] = value
  
  if firefoxStorage.storage['kiwi_servicesInfo']?
    
    # needs to handle entirely new services as well as simplly new attributes
    newServicesInfo = _.extend [], firefoxStorage.storage['kiwi_servicesInfo']
    
    for service_default, index in defaultServicesInfo
      
      matchingService = _.find(firefoxStorage.storage['kiwi_servicesInfo'], (service_info) -> 
        if service_info.name is service_default.name
          return true
        else
          return false
      )
      
      if matchingService?
        
        newServiceObj = _.extend {}, matchingService 
        for keyName, value of service_default
          # console.log keyName
          if typeof matchingService[keyName] is 'undefined'
            
            newServicesInfoAttribute = true
            newServiceObj[keyName] = value
        
        indexOfServiceToReplace = _.indexOf(newServicesInfo, matchingService)
        
        newServicesInfo[indexOfServiceToReplace] = newServiceObj
      else
          # supports adding an entirely new service
        newServicesInfoAttribute = true
          # users that don't download with a specific service will need to opt-in to the new one
        if service_default.active? 
          service_default.active = 'off'
        newServicesInfo.push service_default
  
  if newUserPrefsAttribute or newServicesInfoAttribute
    if newUserPrefsAttribute
      setObj['kiwi_userPreferences'] = newUserPreferences
      
    if newServicesInfoAttribute
      setObj['kiwi_servicesInfo'] = newServicesInfo
    
    # this reminds me of the frog DNA injection from jurassic park
      
    if newUserPrefsAttribute
      firefoxStorage.storage['kiwi_userPreferences'] = newUserPreferences
    
    if newServicesInfoAttribute
      firefoxStorage.storage['kiwi_servicesInfo'] = newServicesInfo
    
    # console.log 'console.debug allItemsInSyncedStorage'
    # console.debug allItemsInSyncedStorage
    
    proceedWithPreInitCheck(overrideSameURLCheck_popupOpen, overrideResearchModeOff,
        sameURLCheck, tabUrl, currentTime, popupOpen)
      
  else
    proceedWithPreInitCheck(overrideSameURLCheck_popupOpen, overrideResearchModeOff,
        sameURLCheck, tabUrl, currentTime, popupOpen)
  
  # a wise coder once told me "try to keep functions to 10 lines or less." yea, welcome to initIfNewURL! let me find my cowboy hat :D
initIfNewURL = (overrideSameURLCheck_popupOpen = false, overrideResearchModeOff = false) ->
  # console.log 'yoyoyo'
  # if firefoxStorage.storage['kiwi_userPreferences']?
  #   console.log 'nothing 0 '
  #   console.log firefoxStorage.storage['kiwi_userPreferences'].researchModeOnOff
  #   # console.debug firefoxStorage.storage['kiwi_userPreferences']
  # else
  #   console.log 'nothing'
  
  if typeof overrideSameURLCheck_popupOpen != 'boolean'
    # ^^ because the Chrome api tab listening functions were exec-ing callback with an integer argument
      # that has since been negated by nesting the callback, but why not leave the check here?
    overrideSameURLCheck_popupOpen = false
  
  # #console.log 'wtf 1 kiwi_urlsResultsCache ' + overrideSameURLCheck_popupOpen
  if overrideSameURLCheck_popupOpen # for when a user turns researchModeOnOff "on" or refreshes results from popup
    popupOpen = true
  else
    popupOpen = false
  
  currentTime = Date.now()
  
  # chrome.tabs.getSelected(null,(tab) ->
    
  # chrome.tabs.query({ currentWindow: true, active: true }, (tabs) ->
    
  if tabs.activeTab.url?
    # console.log 'if tabs.activeTab.url?'
    # console.log tabs.activeTab.url
    # console.log tabs.activeTab
    if tabs.activeTab.url.indexOf('chrome-devtools://') != 0
      
      tabUrl = tabs.activeTab.url
      
      # console.log 'tabUrl = tabs.activeTab.url'
      # console.log tabUrl
      
      # we care about the title, because it's the best way to search google news
      if tabs.activeTab.readyState == 'complete'
        title = tabs.activeTab.title
        
          # a little custom title formatting for sites that begin their tab titles with "(<number>)" like twitter.com
        if title.length > 3 and title[0] == "(" and isNaN(title[1]) == false and title.indexOf(')') != -1 and
            title.indexOf(')') != title.length - 1
          
          title = title.slice(title.indexOf(')') + 1 , title.length).trim()
        
        tabTitleObject = 
          tabTitle: title
          forUrl: tabUrl
          
      else
        
        tabTitleObject = 
          tabTitle: null
          forUrl: tabUrl
      
    else 
      _set_popupParcel({}, tabUrl, false)
      #console.log 'chrome-devtools:// has been the only url visited so far'
      return 0  
    
    
    tabUrl_hash = toSHA512(tabUrl)
    
    sameURLCheck = true
      # firefox's toSHA512 function usually returned a string ending in "=="
    tabUrl_hash = tabUrl_hash.substring(0, tabUrl_hash.length - 2);
    historyString = reduceHashByHalf(tabUrl_hash)
    
    updateBadgeText('')
    
    if !firefoxStorage.storage.persistentUrlHash?
      firefoxStorage.storage.persistentUrlHash = ''
    
    
    if overrideSameURLCheck_popupOpen == false and firefoxStorage.storage['kiwi_historyBlob']? and 
        firefoxStorage.storage['kiwi_historyBlob'].indexOf(historyString) != -1 and 
        (!kiwi_urlsResultsCache? or !kiwi_urlsResultsCache[tabUrl]?)
      
      console.log ' trying to set as old 123412341241234 ' 
      
      updateBadgeText('old')
      sameURLCheck = true
      
      _set_popupParcel({}, tabUrl, false, null, true)
      
      
    else if (overrideSameURLCheck_popupOpen == false and !firefoxStorage.storage.persistentUrlHash?) or 
        firefoxStorage.storage.persistentUrlHash? and firefoxStorage.storage.persistentUrlHash != tabUrl_hash
        
      sameURLCheck = false
      
    
    else if overrideSameURLCheck_popupOpen == true
      sameURLCheck = false
    
    #useful for switching window contexts
    # chrome.storage.local.set({'persistentUrlHash': tabUrl_hash}, ->)
    firefoxStorage.storage['persistentUrlHash'] = tabUrl_hash
    
    if sameURLCheck == false          
      updateBadgeText('')
      checkForNewDefaultUserPreferenceAttributes_thenProceedWithInitCheck(overrideSameURLCheck_popupOpen, 
            overrideResearchModeOff, sameURLCheck, tabUrl, currentTime, popupOpen)
      
tabs.on 'ready', (tab) ->
  # console.log('tab is loaded', tab.title, tab.url)
  initIfNewURL()
  
tabs.on('activate', ->
  # console.log('active: ' + tabs.activeTab.url);
  initIfNewURL()
)

# intial startup
if tabTitleObject == null
  initIfNewURL(true)

  