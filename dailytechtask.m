function dailytechtask
    % Equivalent to:
    % url = "https://techcrunch.com/feed"
    % date = datetime.datetime.now().strftime("%Y-%m-%d")
    % episode = f"tech_{date}"

    % url = "https://techcrunch.com/feed";
    url = "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml";
    % dateStr = datestr(now, 'yyyy-mm-dd');  % "YYYY-MM-DD"
    dt = datetime('now','Format','yyyy-MM-dd');
    dateStr = string(dt);
    % episode = "tech_" + dateStr;
    episode = "nyt_" + dateStr;

    % Get the RSS channel
    channel = rssFeed(url, episode, dateStr);

    % Extract all <item> nodes in the channel
    items = channel.getElementsByTagName('item');
    numItems = items.getLength();
    titles = [];
    % Loop through each item, scrape the article
    for i = 0:(numItems-1)
        itemNode = items.item(i);
        [title, link, textData] = scrapeArticle(itemNode, episode);
        % Optionally display progress
        fprintf('Scraped: %s\n', title);
        fprintf('Link: %s\n',link);
        titles = [titles, title]; 
    end
    alertApiKey = getenv("THINGSPEAK_API_KEY");
    subject = "Daily News "+ dateStr;
    body = strjoin(titles, newline);
    body = extractBefore(body, 255);
    sendEmail(alertApiKey,subject,body)
end

function channel = rssFeed(url, episode, dateStr)
    % RSS-like function to mimic:
    %    def rss(url, episode, date):
    %        response = requests.get(url)
    %        ...

    % Get the RSS data from the feed URL as text
    response = webread(url);  % returns a character vector

    % Parse the XML from the response string
    doc = parseXMLString(response);

    % Get the <channel> element
    channel = doc.getElementsByTagName('channel').item(0);
    rssFile = fullfile("podcast", episode, "rss_" + dateStr + ".xml");
    fid = fopen(rssFile, 'w');
    fwrite(fid, response);
    fclose(fid);
end

function [title, link, textData] = scrapeArticle(itemNode, episode)
    % Mimics:
    %   def scrape_article(item, episode):
    %       title = item.find('title').text
    %       link = item.find('link').text
    %       ...

    % Extract title text from <title> node
    title = string(itemNode.getElementsByTagName('title').item(0).getFirstChild.getData());
    % Replace forbidden characters with '-'
    title = regexprep(title, '[<>:"/\\|?*]', '-');

    % Extract link text from <link> node
    link = string(itemNode.getElementsByTagName('link').item(0).getFirstChild.getData());

    % Fetch HTML of the article
    html = webread(link);

    % In MATLAB R2021b or later, you can parse HTML with htmlTree
    tree = htmlTree(html);

    % Find core of the article
    if contains(link, "techcrunch", 'IgnoreCase', true)
        % TechCrunch articles typically use the '.entry-content' class
        entryContent = findElement(tree, '.entry-content');
    elseif contains(link, "nytimes", 'IgnoreCase', true)
        % NYTimes articles may have the article body within a <section> with name="articleBody"
        entryContent = findElement(tree, 'section[name="articleBody"]');
    else
        % Optionally, add a default extraction or handle unknown sources here
        entryContent = [];
    end
    if ~isempty(entryContent)
        % Extract readable text
        textData = extractHTMLText(entryContent(1));
    else
        textData = ''; % fallback if no match
    end

    % Save text content
    textFolder = fullfile("podcast", episode, "text");
    if ~exist(textFolder, 'dir')
        mkdir(textFolder);
    end
    textFile = fullfile(textFolder, title + ".txt");

    fid = fopen(textFile, 'w', 'n', 'UTF-8');
    fwrite(fid, textData, 'char');
    fclose(fid);
end


function doc = parseXMLString(xmlString)
    % Helper to parse XML from string in MATLAB
    tempFile = [tempname, '.xml'];
    fid = fopen(tempFile, 'w');
    fwrite(fid, xmlString, 'char');
    fclose(fid);

    doc = xmlread(tempFile);  % Parse the file as XML Document Object
    delete(tempFile);
end


function sendEmail(alertApiKey,subject,body)
    % Provide the ThingSpeak alerts API key.  All alerts API keys start with TAK.    
    % webwrite uses weboptions to add required headers.  Alerts needs a ThingSpeak-Alerts-API-Key header.
    options = weboptions("HeaderFields", ["ThingSpeak-Alerts-API-Key", alertApiKey ]);
    webwrite("https://api.thingspeak.com/alerts/send", "body", body, "subject", subject, options);
end