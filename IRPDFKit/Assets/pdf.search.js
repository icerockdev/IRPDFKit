
PDFJS.workerSrc = 'pdf.worker.js';

var documentData = null;

function getParameterByName(name) {
  var match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search);
  return match && decodeURIComponent(match[1].replace(/\+/g, ' '));
}

function getDocumentData(file) {
  documentData = null;
  
  PDFJS
    .getDocument({url: file})
    .then(function (pdfDocument) {
          var pages = [];
          for(var i = 0; i < pdfDocument.numPages; i++) {
            var prom = getPageData(pdfDocument, i + 1);
            pages.push(prom);
          }
          return Promise.all(pages);
          })
    .then(function (pages) {
          documentData = JSON.stringify(pages);
          });
}

function getPageData(document, pageIdx) {
  return document
    .getPage(pageIdx)
    .then(function (page) {
          return page.getTextContent();
          })
    .then(function (textContent) {
          return {
            "page": pageIdx,
            "content": textContent
            };
          });
}

var fileUrl = getParameterByName("file");
getDocumentData(fileUrl);
