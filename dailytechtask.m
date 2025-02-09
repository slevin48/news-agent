function dailytechtask
    % Equivalent to:
    % url = "https://techcrunch.com/feed"
    % date = datetime.datetime.now().strftime("%Y-%m-%d")
    % episode = f"tech_{date}"

    url = "https://techcrunch.com/feed";
    % dateStr = datestr(now, 'yyyy-mm-dd');  % "YYYY-MM-DD"
    dt = datetime('now','Format','yyyy-MM-dd');
    dateStr = string(dt);
    episode = "tech_" + dateStr;

    % Get the RSS channel
    channel = rssFeed(url, episode, dateStr);

    % Extract all <item> nodes in the channel
    items = channel.getElementsByTagName('item');
    numItems = items.getLength();

    % Loop through each item, scrape the article
    for i = 0:(numItems-1)
        itemNode = items.item(i);
        [title, link, textData] = scrapeArticle(itemNode, episode);
        % Optionally display progress
        fprintf('Scraped: %s\n', title);
        fprintf('Link: %s\n',link);
    end
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

    % Save the entire RSS feed to a file
    rssFolder = fullfile("podcast", episode, "rss");
    if ~exist(rssFolder, 'dir')
        mkdir(rssFolder);
    end

    rssFile = fullfile(rssFolder, "techcrunch_" + dateStr + ".xml");
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
    title = char(itemNode.getElementsByTagName('title').item(0).getFirstChild.getData());
    % Replace forbidden characters with '-'
    title = regexprep(title, '[<>:"/\\|?*]', '-');

    % Extract link text from <link> node
    link = char(itemNode.getElementsByTagName('link').item(0).getFirstChild.getData());

    % Fetch HTML of the article
    html = webread(link);

    % In MATLAB R2021b or later, you can parse HTML with htmlTree
    tree = htmlTree(html);

    % Find elements whose class="entry-content"
    % entryContent = findElement(tree, 'class', 'entry-content');
    entryContent = findElement(tree, '.entry-content');

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
