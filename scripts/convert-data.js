#!/usr/bin/env node
/**
 * Convert WaniKani data from JS to JSON format for iOS app
 * Processes kanji, radicals, and vocabulary data
 */

const fs = require('fs');
const path = require('path');

// Source paths
const sourceDir = path.join(__dirname, '../../kanji-memory/kanji-memory-next/public');
const dataDir = path.join(__dirname, '../../kanji-memory/kanji-memory-next/public/data');

// Output paths
const outputDir = path.join(__dirname, '../KanjiMemory/Resources/Data');

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

console.log('📦 Converting WaniKani data to JSON...\n');

// 1. Convert kanji data from JS
console.log('🔄 Processing kanji data...');
const kanjiJsContent = fs.readFileSync(
    path.join(sourceDir, 'wanikani-kanji-data.js'),
    'utf8'
);

// Extract kanjiData object using regex
const kanjiMatch = kanjiJsContent.match(/const kanjiData = ({[\s\S]*?});/);
if (!kanjiMatch) {
    console.error('❌ Could not find kanjiData in wanikani-kanji-data.js');
    process.exit(1);
}

// Parse the JSON-like structure
let kanjiDataStr = kanjiMatch[1];
// The JS object is already valid JSON format
const kanjiData = eval(`(${kanjiDataStr})`);

// Extract radical character map
const radicalMapMatch = kanjiJsContent.match(/const wanikaniRadicalCharMap = ({[\s\S]*?});/);
let radicalCharMap = {};
if (radicalMapMatch) {
    radicalCharMap = eval(`(${radicalMapMatch[1]})`);
}

// Process kanji data - flatten for iOS
const allKanji = [];
const kanjiByLevel = {};

Object.entries(kanjiData).forEach(([level, kanjiList]) => {
    kanjiByLevel[level] = kanjiList.map(kanji => ({
        character: kanji.character,
        meanings: kanji.meanings,
        onyomi: kanji.onyomi || [],
        kunyomi: kanji.kunyomi || [],
        radicals: kanji.radicals || [],
        strokeCount: kanji.strokeCount || 0,
        wanikaniId: kanji.wanikaniId,
        level: parseInt(level),
        // Vocabulary is stored separately
    }));
    allKanji.push(...kanjiByLevel[level]);
});

// Save kanji data
fs.writeFileSync(
    path.join(outputDir, 'kanji_all.json'),
    JSON.stringify({ levels: kanjiByLevel, count: allKanji.length }, null, 2)
);
console.log(`   ✅ Saved ${allKanji.length} kanji to kanji_all.json`);

// 2. Process radicals data
console.log('🔄 Processing radicals data...');
const radicalsComplete = JSON.parse(
    fs.readFileSync(path.join(dataDir, 'radicals-complete.json'), 'utf8')
);

// radicals-complete.json is wrapped in an array
const radicalsData = radicalsComplete[0];
const allRadicals = [];
const radicalsByLevel = {};

Object.entries(radicalsData).forEach(([level, radicalsList]) => {
    radicalsByLevel[level] = radicalsList.map(radical => ({
        id: radical.id,
        characters: radical.characters,
        image: radical.image || null, // Image name for radicals without characters
        meanings: radical.meanings.map(m =>
            typeof m === 'string' ? { meaning: m, primary: true } : m
        ),
        level: parseInt(level),
        slug: radical.slug || ''
    }));
    allRadicals.push(...radicalsByLevel[level]);
});

fs.writeFileSync(
    path.join(outputDir, 'radicals_all.json'),
    JSON.stringify({ levels: radicalsByLevel, count: allRadicals.length }, null, 2)
);
console.log(`   ✅ Saved ${allRadicals.length} radicals to radicals_all.json`);

// 3. Process vocabulary data
console.log('🔄 Processing vocabulary data...');
const vocabularyComplete = JSON.parse(
    fs.readFileSync(path.join(dataDir, 'vocabulary-complete.json'), 'utf8')
);

// vocabulary-complete.json is wrapped in an array
const vocabularyData = vocabularyComplete[0];
const allVocabulary = [];
const vocabularyByLevel = {};

Object.entries(vocabularyData).forEach(([level, vocabList]) => {
    vocabularyByLevel[level] = vocabList.map(vocab => ({
        id: vocab.id,
        characters: vocab.characters,
        meanings: vocab.meanings.map(m =>
            typeof m === 'string' ? { meaning: m, primary: true } : m
        ),
        readings: vocab.readings.map(r =>
            typeof r === 'string' ? { reading: r, primary: true } : r
        ),
        level: parseInt(level),
        slug: vocab.slug || vocab.characters
    }));
    allVocabulary.push(...vocabularyByLevel[level]);
});

fs.writeFileSync(
    path.join(outputDir, 'vocabulary_all.json'),
    JSON.stringify({ levels: vocabularyByLevel, count: allVocabulary.length }, null, 2)
);
console.log(`   ✅ Saved ${allVocabulary.length} vocabulary to vocabulary_all.json`);

// 4. Save radical character map
fs.writeFileSync(
    path.join(outputDir, 'radical_char_map.json'),
    JSON.stringify(radicalCharMap, null, 2)
);
console.log(`   ✅ Saved ${Object.keys(radicalCharMap).length} radical mappings to radical_char_map.json`);

// 5. Create metadata file
const metadata = {
    generatedAt: new Date().toISOString(),
    counts: {
        kanji: allKanji.length,
        radicals: allRadicals.length,
        vocabulary: allVocabulary.length
    },
    levels: {
        min: 1,
        max: 60
    },
    version: '1.0.0'
};

fs.writeFileSync(
    path.join(outputDir, 'metadata.json'),
    JSON.stringify(metadata, null, 2)
);
console.log(`   ✅ Saved metadata.json`);

console.log('\n✨ Data conversion complete!');
console.log(`   📁 Output directory: ${outputDir}`);
console.log(`   📊 Total items: ${allKanji.length + allRadicals.length + allVocabulary.length}`);
