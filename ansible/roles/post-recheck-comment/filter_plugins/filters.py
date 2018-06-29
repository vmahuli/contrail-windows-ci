#!/usr/bin/env python2

import json

def select_reviewer_messages(command, username):
    query_result = json.loads(command['stdout_lines'][0])
    comments = query_result['comments']
    messages = [
        comment['message']
        for comment in comments
        if comment['reviewer']['username'] == username
    ]
    return messages


class FilterModule(object):
    def filters(self):
        return {
            'select_reviewer_messages': select_reviewer_messages,
        }
