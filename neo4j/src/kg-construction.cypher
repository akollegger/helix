/**
  * Load a book, chunk it up.
  * 
  * The process is:
  * 
  * 1. Load a book from a json file
  * 2. Migrate the text sections of the Form 10-K to `(:Chunk)` nodes, one per section
  * 3. Connect `(:Form)-[:SECTION]->(:Chunk)` relationships
  * 4. Split each section text into chunks of 1000 words and create a `(:Chunk)` for each chunk
  * 5. Create a linked list of `(:Chunk)-[:NEXT]->(:Chunk)` relationships
  * 6. Generate embeddings for each chunk using the OpenAI API
  * 7. Load Form 13 data from a CSV file, creating `(:Company)` and `(:Manager)` nodes
  * 8. Create `(:Manager)-[:OWNS_STOCK_IN]->(:Company)` relationships
  * 9. Connect `(:Company)-[:FILED]->(:Form)` relationships
  *
  * The resulting graph will look like this:
  *
  * @graph ```
  * (:Book => { 
  *     author :: string!,   // book author
  *     title :: string,   // book title
  *     summary :: string,   // text summary generated with the LLM **NOTE: not yet implemented! **
  *     summaryEmbeddings: list<float> // vector embedding of summary **NOTE: not yet implemented! **
  * })
  *
  * (:Chunk => {
  *    chunkId :: string!,  // a unique identifier for the chunk
  *    text :: string!,     // the text of the chunk 
  *    textEmbedding :: list<float> // vector embedding of the text
  * })
  * 
  * (:Form)=[:SECTION => { item :: string }]=>(:Chunk)
  *
  * // @kind peer
  * // @antonym previous
  * (:Chunk)=[:NEXT^1]=>(:Chunk)
  *
  * // @kind membership
  * (:Chunk)=[:PART_OF^1]->(:Form)
  *
  * (:Company => {
  *     cusip6:: string!,       // the CUSIP6 identifier for the company
  *     name :: string!,        // the name of the company
  *     names :: list<string>,  // list of alternative names for the company
  *     cusip:: list<string>,   // list of known CUSIP identifiers for the company
  *     address :: string       // the address of the company **NOTE: not yet implemented! **
  * })
  *
  * (:Manager {
  *     cik :: int!, // the Central Index Key for the manager
  *     name :: string, // the name of the manager
  *     address :: string // the address of the manager
  * })
  * 
  * (:Manager)=[:OWNS_STOCK_IN]=>(:Company)
  * (:Company)=[:FILED]=>(:Form)
  * ```
  *
  * @module LoadEdgarKG
  * @plugins apoc, genai
  * @param openAiApiKey::string - OpenAI API key
  * @param baseURL::string - Base URL for the data files
  */
MERGE (kg:KnowledgeGraph {name: "Books"})
MERGE (kgop:KnowledgeGraphOperation {name: "Construction", source:"kg-construction.cypher"})
  ON MATCH SET kgop.lastRun = datetime()
MERGE (kgop)-[:APPLIED_TO]->(kg)
RETURN kg.name + "-" + kgop.name as as name // first statement in a module must RETURN module name
;

////////////////////////////////////////////////
// Load a book, split it up into chapters
;

// create a book node with title and author, return book with array of chapters
WITH "file://alice.json" as blog_url
CALL apoc.load.json(blog_url) YIELD value
MERGE (book:Book { title: value.metadata.title, author: value.metadata.author })
WITH book, value.content as bookContent
WITH book, bookContent,  apoc.text.split(bookContent, "CHAPTER") as splitChapters
WITH book, bookContent, splitChapters[0] + [chapter in splitChapters[1..] | "CHAPTER " + chapter] as chapters
RETURN book, chapters
;
// return chapter titles using a subquery per chapter, extracting with a regex
WITH "file://alice.json" as blog_url
CALL apoc.load.json(blog_url) YIELD value
MERGE (book:Book { title: value.metadata.title, author: value.metadata.author })
WITH book, value.content as bookContent
WITH book, bookContent,  apoc.text.split(bookContent, "CHAPTER") as splitChapters
WITH book, bookContent, splitChapters[0] + [chapter in splitChapters[1..] | "CHAPTER " + chapter] as chapters
CALL {
  WITH book, chapters
  UNWIND chapters as chapter
  WITH apoc.text.regexGroups(chapter, "CHAPTER.*\n(.*)") as chapterTitleGroup
  RETURN CASE size(chapterTitleGroup) 
    WHEN > 0 THEN chapterTitleGroup[0][1] // as long as we have more than 0 groups, return the first one
    ELSE null 
  END as chapterTitle
}
RETURN book, chapterTitle
;
// return chapter numbers and titles, using an expanded regex
WITH "file://alice.json" as blog_url
CALL apoc.load.json(blog_url) YIELD value
MERGE (book:Book { title: value.metadata.title, author: value.metadata.author })
WITH book, value.content as bookContent
WITH book, bookContent,  apoc.text.split(bookContent, "CHAPTER") as splitChapters
WITH book, bookContent, splitChapters[0] + [chapter in splitChapters[1..] | "CHAPTER " + chapter] as chapters
CALL {
  WITH book, chapters
  UNWIND chapters as chapter
  WITH book, chapter, apoc.text.regexGroups(chapter, "CHAPTER\s+([IXV]+).*\n(.*)") as chapterTitleGroups
  WITH book, chapter, chapterTitleGroups,
    CASE size(chapterTitleGroups)
      WHEN > 0 THEN chapterTitleGroups[0][2]
      ELSE "INTRO"
    END as chapterTitle,
    CASE size(chapterTitleGroups)
      WHEN > 0 THEN chapterTitleGroups[0][1]
      ELSE ""
    END as chapterNumber
  RETURN chapter, chapterNumber, chapterTitle, chapterTitleGroups
}
RETURN chapterNumber, chapterTitle, chapterTitleGroups
;
// CREATE book and chapter nodes, return book and first chapter
WITH "https://raw.githubusercontent.com/akollegger/helix/main/neo4j/import/alice.json" as blog_url
CALL apoc.load.json(blog_url) YIELD value
MERGE (book:Book { title: value.metadata.title, author: value.metadata.author })
WITH book, value.content as bookContent
WITH book, bookContent,  apoc.text.split(bookContent, "CHAPTER") as splitChapters
WITH book, bookContent, splitChapters[0] + [chapter in splitChapters[1..] | "CHAPTER " + chapter] as chapters
CALL {
  WITH book, chapters
  UNWIND chapters as chapterText
  WITH book, chapterText, apoc.text.regexGroups(chapterText, "CHAPTER\s+([IXV]+).*\n(.*)") as chapterTitleGroups
  WITH book, chapterText, chapterTitleGroups,
    CASE size(chapterTitleGroups)
      WHEN > 0 THEN chapterTitleGroups[0][2]
      ELSE "INTRO"
    END as chapterTitle,
    CASE size(chapterTitleGroups)
      WHEN > 0 THEN chapterTitleGroups[0][1]
      ELSE ""
    END as chapterNumber
  MERGE (chapter:Chapter { title: chapterTitle, number: chapterNumber })
  SET chapter.text = chapterText
  MERGE (book)-[:CHAPTER {number: chapterNumber}]->(chapter)
  WITH collect(chapter) as chapterList
  CALL apoc.nodes.link(chapterList, "NEXT",{avoidDuplicates:true})
}
MATCH p=(:Book)-->(:Chapter) RETURN p
;
// Splt the chapter text into chunks of 1000 words
MATCH (b:Book)-[s:CHAPTER]->(c:Chapter)
WITH b, s, c, apoc.text.split(c.text, "\s+") as tokens
CALL apoc.coll.partition(tokens, 1000) YIELD value
WITH b, s, c, apoc.text.join(value, " ") as chunk
WITH b, s, c, collect(chunk) as chunks
RETURN b.title, s.number, c.title, size(chunks)
;
// create chunk nodes and connect them in a linked list
MATCH (bk:Book)-[:CHAPTER]->(chpt:Chapter)
  WHERE NOT (chpt)<-[:PART_OF]-()
WITH bk, chpt, apoc.text.split(chpt.text, "\s+") as tokens
CALL apoc.coll.partition(tokens, 1000) YIELD value
WITH bk, chpt, apoc.text.join(value, " ") as chunk
WITH bk, chpt, collect(chunk) as chunks
CALL {
    WITH chpt, chunks
    WITH chpt, chunks, [idx in range(0, size(chunks) -1) | 
         { text: chunks[idx] }] as chunkProps 
    CALL apoc.create.nodes(["Chunk"], chunkProps) yield node
    MERGE (node)-[:PART_OF]->(chpt)
    WITH chpt, collect(node) as chunkNodes
    CALL apoc.nodes.link(chunkNodes, 'NEXT')
    WITH chpt, head(chunkNodes) as begin
    MERGE (chpt)-[:BEGINNING]->(begin)
    RETURN begin
}
RETURN bk, chpt, begin
;
