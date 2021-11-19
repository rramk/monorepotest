'use strict'

/**
 * @description echo function
 * @param {array} args variable number of args
 * @return {void}
 */
function echo(...args) {
  console.log(`Hello ${args}`);
}

module.exports = {
  echo
};
